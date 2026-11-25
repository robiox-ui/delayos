"""File operations for 파일 탐색기: copy / move / trash (freedesktop Trash spec) / restore / delete / zip / extract."""
import datetime
import os
import shutil
import stat
import urllib.parse
import zipfile

HOME = os.path.expanduser("~")
TRASH = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.join(HOME, ".local/share")), "Trash")
TRASH_FILES = os.path.join(TRASH, "files")
TRASH_INFO = os.path.join(TRASH, "info")


def unique_name(dirpath, name):
    """'a.txt' -> 'a (2).txt' if taken."""
    if not os.path.lexists(os.path.join(dirpath, name)):
        return name
    base, ext = os.path.splitext(name)
    if base.endswith(".tar"):
        base, ext = base[:-4], ".tar" + ext
    n = 2
    while True:
        cand = "%s (%d)%s" % (base, n, ext)
        if not os.path.lexists(os.path.join(dirpath, cand)):
            return cand
        n += 1


def copy_into(src, dstdir, progress=None):
    name = unique_name(dstdir, os.path.basename(src.rstrip("/")))
    dst = os.path.join(dstdir, name)
    if os.path.isdir(src) and not os.path.islink(src):
        if os.path.abspath(dstdir).startswith(os.path.abspath(src) + os.sep) or os.path.abspath(dstdir) == os.path.abspath(src):
            raise OSError("폴더를 자기 자신 안으로 복사할 수 없어요")
        shutil.copytree(src, dst, symlinks=True, copy_function=_copy_fn(progress))
    else:
        shutil.copy2(src, dst, follow_symlinks=False)
        if progress:
            progress(os.path.getsize(dst) if not os.path.islink(dst) else 0)
    return dst


def _copy_fn(progress):
    def fn(s, d, **kw):
        shutil.copy2(s, d, **kw)
        if progress:
            try:
                progress(os.path.getsize(d))
            except OSError:
                pass
    return fn


def move_into(src, dstdir):
    if os.path.dirname(os.path.abspath(src)) == os.path.abspath(dstdir):
        return src
    if os.path.isdir(src) and (os.path.abspath(dstdir) + os.sep).startswith(os.path.abspath(src) + os.sep):
        raise OSError("폴더를 자기 자신 안으로 옮길 수 없어요")
    name = unique_name(dstdir, os.path.basename(src.rstrip("/")))
    dst = os.path.join(dstdir, name)
    shutil.move(src, dst)
    return dst


def trash(path):
    """Move to ~/.local/share/Trash. Returns the name inside Trash/files."""
    os.makedirs(TRASH_FILES, exist_ok=True)
    os.makedirs(TRASH_INFO, exist_ok=True)
    name = os.path.basename(path.rstrip("/"))
    tname = name
    n = 2
    while os.path.lexists(os.path.join(TRASH_FILES, tname)) or os.path.exists(os.path.join(TRASH_INFO, tname + ".trashinfo")):
        base, ext = os.path.splitext(name)
        tname = "%s.%d%s" % (base, n, ext)
        n += 1
    info = os.path.join(TRASH_INFO, tname + ".trashinfo")
    with open(info, "w", encoding="utf-8") as f:
        f.write("[Trash Info]\nPath=%s\nDeletionDate=%s\n" % (
            urllib.parse.quote(os.path.abspath(path)), datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")))
    try:
        shutil.move(path, os.path.join(TRASH_FILES, tname))
    except OSError:
        os.remove(info)
        raise
    _bump_trash_dirsizes()
    return tname


def _bump_trash_dirsizes():
    try:
        os.remove(os.path.join(TRASH, "directorysizes"))
    except OSError:
        pass


def trash_items():
    out = []
    if not os.path.isdir(TRASH_INFO):
        return out
    for fn in os.listdir(TRASH_INFO):
        if not fn.endswith(".trashinfo"):
            continue
        tname = fn[:-10]
        p = os.path.join(TRASH_FILES, tname)
        if not os.path.lexists(p):
            continue
        orig, date = "", ""
        try:
            with open(os.path.join(TRASH_INFO, fn), encoding="utf-8", errors="replace") as f:
                for line in f:
                    if line.startswith("Path="):
                        orig = urllib.parse.unquote(line[5:].strip())
                    elif line.startswith("DeletionDate="):
                        date = line[13:].strip()
        except OSError:
            continue
        out.append({"tname": tname, "path": p, "orig": orig, "date": date})
    return out


def restore(tname):
    p = os.path.join(TRASH_FILES, tname)
    info = os.path.join(TRASH_INFO, tname + ".trashinfo")
    orig = None
    with open(info, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("Path="):
                orig = urllib.parse.unquote(line[5:].strip())
    if not orig:
        raise OSError("원래 위치를 알 수 없어요")
    d = os.path.dirname(orig)
    os.makedirs(d, exist_ok=True)
    dst = os.path.join(d, unique_name(d, os.path.basename(orig)))
    shutil.move(p, dst)
    os.remove(info)
    _bump_trash_dirsizes()
    return dst


def delete_forever(path):
    if os.path.isdir(path) and not os.path.islink(path):
        def onerr(func, p, exc):
            try:
                os.chmod(p, stat.S_IWUSR | stat.S_IRUSR | stat.S_IXUSR)
                func(p)
            except OSError:
                pass
        shutil.rmtree(path, onerror=onerr)
    else:
        os.remove(path)
    if path.startswith(TRASH_FILES + os.sep):
        info = os.path.join(TRASH_INFO, os.path.basename(path) + ".trashinfo")
        try:
            os.remove(info)
        except OSError:
            pass


def empty_trash():
    for it in trash_items():
        try:
            delete_forever(it["path"])
        except OSError:
            pass
    for d in (TRASH_FILES, TRASH_INFO):
        if os.path.isdir(d):
            for fn in os.listdir(d):
                p = os.path.join(d, fn)
                try:
                    delete_forever(p)
                except OSError:
                    pass
    _bump_trash_dirsizes()


def zip_paths(paths, dstdir):
    if len(paths) == 1:
        base = os.path.splitext(os.path.basename(paths[0].rstrip("/")))[0] if not os.path.isdir(paths[0]) else os.path.basename(paths[0].rstrip("/"))
    else:
        base = "압축"
    name = unique_name(dstdir, base + ".zip")
    out = os.path.join(dstdir, name)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in paths:
            root = os.path.dirname(os.path.abspath(p))
            if os.path.isdir(p) and not os.path.islink(p):
                for dp, dns, fns in os.walk(p):
                    rel = os.path.relpath(dp, root)
                    z.write(dp, rel)
                    for fn in fns:
                        fp = os.path.join(dp, fn)
                        z.write(fp, os.path.relpath(fp, root))
            else:
                z.write(p, os.path.basename(p))
    return out


def extract_here(path):
    dstdir = os.path.dirname(path)
    base = os.path.splitext(os.path.basename(path))[0]
    if base.endswith(".tar"):
        base = base[:-4]
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            names = z.namelist()
            tops = {n.split("/")[0] for n in names if n}
            if len(tops) == 1 and any("/" in n for n in names):
                target = dstdir
                top = tops.pop()
                if os.path.exists(os.path.join(dstdir, top)):
                    target = os.path.join(dstdir, unique_name(dstdir, base))
                    os.makedirs(target)
            else:
                target = os.path.join(dstdir, unique_name(dstdir, base))
                os.makedirs(target)
            for m in z.infolist():
                fn = os.path.normpath(m.filename)
                if fn.startswith("..") or os.path.isabs(fn):
                    continue
                z.extract(m, target)
        return target
    shutil.unpack_archive(path, os.path.join(dstdir, unique_name(dstdir, base)))
    return dstdir


def dir_size(path, limit=200000):
    total, n = 0, 0
    for dp, dns, fns in os.walk(path):
        for fn in fns:
            try:
                total += os.lstat(os.path.join(dp, fn)).st_size
            except OSError:
                pass
            n += 1
            if n > limit:
                return total, n, True
    return total, n, False
