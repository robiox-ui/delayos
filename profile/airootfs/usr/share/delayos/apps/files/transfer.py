"""Copy / move job for 파일 탐색기 (drag and drop, paste): progress, cancel, name conflicts, undo records.

A Job runs in a worker thread. It never touches Qt: the owner passes two callables,
    ask(info: dict) -> (choice, apply_to_all)    choice: "overwrite" | "skip" | "keep" | "cancel"   (blocks)
    progress(job)                                called at most ~12 times a second
Undo records collected in job.done (newest last, undone in reverse):
    ("copy", dst)             the copy is moved to the trash
    ("move", src, dst)        moved back
    ("replaced", dst, tname)  an overwritten item that went to the trash first; restored
"""
import errno
import os
import shutil
import stat
import threading
import time

import fileops

CHUNK = 8 << 20
SCAN_LIMIT = 200000


class Cancelled(Exception):
    pass


def is_real_dir(p):
    return os.path.isdir(p) and not os.path.islink(p)


def same_device(src, dstdir):
    try:
        return os.lstat(src).st_dev == os.stat(dstdir).st_dev
    except OSError:
        return False


def inside(child, parent):
    """True when `child` is `parent` or lies below it."""
    c, p = os.path.abspath(child), os.path.abspath(parent)
    return c == p or c.startswith(p.rstrip(os.sep) + os.sep)


class Job:
    def __init__(self, paths, dstdir, copy, ask, progress):
        self.paths = list(paths)
        self.dstdir = dstdir
        self.copy = copy
        self._ask = ask
        self._progress = progress
        self.cancel = threading.Event()
        self.done = []
        self.policy = None            # set by "apply to all"
        self.total = 0                # bytes (copy) or items (rename)
        self.pos = 0
        self.exact = True             # False: the scan hit its limit, show an indeterminate bar
        self.by_bytes = True
        self.current = ""
        self.count = len(self.paths)
        self.skipped = 0
        self.conflicts_left = 0
        self._last = 0.0
        self.started = time.monotonic()

    # ---------- helpers ----------
    def _check(self):
        if self.cancel.is_set():
            raise Cancelled()

    def _tick(self, n, name=None, force=False):
        self.pos += n
        if name is not None:
            self.current = name
        now = time.monotonic()
        if force or now - self._last > 0.08:
            self._last = now
            self._progress(self)

    def _scan(self):
        """Total size, and how many top-level names already exist in the target."""
        renames = not self.copy and all(same_device(p, self.dstdir) for p in self.paths)
        self.by_bytes = not renames
        clash = 0
        for p in self.paths:
            d = os.path.join(self.dstdir, os.path.basename(p.rstrip("/")))
            if os.path.lexists(d) and os.path.abspath(os.path.dirname(p)) != os.path.abspath(self.dstdir):
                clash += 1
        self.conflicts_left = clash
        if renames:
            self.total = len(self.paths)
            return
        n = 0
        for p in self.paths:
            self._check()
            if not is_real_dir(p):
                try:
                    self.total += os.lstat(p).st_size
                except OSError:
                    pass
                n += 1
                continue
            for dp, _dns, fns in os.walk(p):
                self._check()
                for fn in fns:
                    try:
                        self.total += os.lstat(os.path.join(dp, fn)).st_size
                    except OSError:
                        pass
                n += len(fns)
                if n > SCAN_LIMIT:
                    self.exact = False
                    return

    def _resolve(self, src, dst):
        if self.policy:
            return self.policy
        self.conflicts_left = max(0, self.conflicts_left - 1)
        info = {"name": os.path.basename(dst), "src": src, "dst": dst, "dir": os.path.dirname(dst),
                "isDir": is_real_dir(src) and is_real_dir(dst), "more": self.conflicts_left}
        for key, p in (("srcStat", src), ("dstStat", dst)):
            try:
                st = os.lstat(p)
                info[key] = (st.st_size, st.st_mtime, is_real_dir(p))
            except OSError:
                info[key] = (0, 0, False)
        choice, to_all = self._ask(info)
        if choice == "cancel":
            self.cancel.set()
            raise Cancelled()
        if to_all:
            self.policy = choice
        return choice

    # ---------- copying ----------
    def _copy_file(self, src, dst):
        name = os.path.basename(src)
        try:
            with open(src, "rb") as fi, open(dst, "wb") as fo:
                size = os.fstat(fi.fileno()).st_size
                use_cfr = hasattr(os, "copy_file_range")
                buf = None
                done = 0
                while True:
                    self._check()
                    n = 0
                    if use_cfr:
                        try:
                            # reflink / server-side copy where the filesystem can (btrfs: instant)
                            n = os.copy_file_range(fi.fileno(), fo.fileno(), CHUNK)
                        except OSError as e:
                            if done or e.errno not in (errno.EXDEV, errno.EINVAL, errno.ENOSYS, errno.EOPNOTSUPP,
                                                       errno.EPERM, errno.EBADF, errno.ETXTBSY):
                                raise
                            use_cfr = False
                            continue
                    else:
                        if buf is None:
                            buf = memoryview(bytearray(1 << 20))
                        n = fi.readinto(buf)
                        if n:
                            fo.write(buf[:n])
                    if not n:
                        break
                    done += n
                    self._tick(n, name)
                if size == 0:
                    self._tick(0, name)
        except BaseException:
            try:
                os.remove(dst)
            except OSError:
                pass
            raise
        try:
            shutil.copystat(src, dst, follow_symlinks=False)
        except OSError:
            pass

    def _copy_tree(self, src, dst):
        self._check()
        if os.path.islink(src):
            os.symlink(os.readlink(src), dst)
            return
        if os.path.isdir(src):
            os.mkdir(dst)
            with os.scandir(src) as it:
                entries = list(it)
            for e in entries:
                self._copy_tree(e.path, os.path.join(dst, e.name))
            try:
                shutil.copystat(src, dst, follow_symlinks=False)
            except OSError:
                pass
            return
        st = os.lstat(src)
        if stat.S_ISREG(st.st_mode):
            self._copy_file(src, dst)
        elif stat.S_ISFIFO(st.st_mode):
            os.mkfifo(dst)
        # sockets and device nodes are skipped

    def _place(self, src, dst):
        name = os.path.basename(src.rstrip("/"))
        if self.copy:
            self.current = name
            try:
                self._copy_tree(src, dst)
            except BaseException:
                if os.path.lexists(dst):
                    try:
                        fileops.delete_forever(dst)       # no half-copied folders left behind
                    except OSError:
                        pass
                raise
            self.done.append(("copy", dst))
            return
        try:
            os.rename(src, dst)
            if not self.by_bytes:
                self._tick(1, name)
        except OSError as e:
            if e.errno != errno.EXDEV:
                raise
            self.by_bytes or self._tick(0, name)
            try:
                self._copy_tree(src, dst)
            except BaseException:
                if os.path.lexists(dst):
                    try:
                        fileops.delete_forever(dst)
                    except OSError:
                        pass
                raise
            fileops.delete_forever(src)
        self.done.append(("move", src, dst))

    def _discard(self, dst):
        """An item about to be overwritten: to the trash when that is a rename, else deleted."""
        os.makedirs(fileops.TRASH_FILES, exist_ok=True)
        if same_device(dst, fileops.TRASH_FILES):
            self.done.append(("replaced", dst, fileops.trash(dst)))
        else:
            fileops.delete_forever(dst)

    def _merge(self, src, dst):
        """Folder onto a folder of the same name: contents are merged, same-named files replaced."""
        with os.scandir(src) as it:
            names = [e.name for e in it]
        saved, self.policy = self.policy, self.policy or "overwrite"
        try:
            for n in names:
                self._transfer(os.path.join(src, n), dst)
        finally:
            self.policy = saved
        if not self.copy:
            try:
                os.rmdir(src)
            except OSError:
                pass
        return dst

    def _transfer(self, src, dstdir):
        self._check()
        name = os.path.basename(src.rstrip("/"))
        dst = os.path.join(dstdir, name)
        src_dir = is_real_dir(src)
        if os.path.abspath(os.path.dirname(src.rstrip("/"))) == os.path.abspath(dstdir):
            if not self.copy:
                return ""                                   # moved onto its own folder: nothing to do
            dst = os.path.join(dstdir, fileops.copy_name(dstdir, name))
        elif src_dir and inside(dstdir, src):
            raise OSError("폴더를 자기 자신 안으로 %s 수 없어요" % ("복사할" if self.copy else "옮길"))
        elif os.path.lexists(dst):
            choice = self._resolve(src, dst)
            if choice == "skip":
                self.skipped += 1
                return ""
            if choice == "keep":
                dst = os.path.join(dstdir, fileops.unique_name(dstdir, name))
            elif src_dir and is_real_dir(dst):
                return self._merge(src, dst)
            else:
                self._discard(dst)
        self._place(src, dst)
        return dst

    def run(self):
        """Returns the last path created (to select it). Raises Cancelled / OSError; job.done stays valid."""
        self._scan()
        self._tick(0, "", force=True)
        last = ""
        for p in self.paths:
            last = self._transfer(p, self.dstdir) or last
        self._tick(0, force=True)
        return last
