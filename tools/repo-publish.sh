#!/usr/bin/env bash
# Signs the local pool and publishes it to the DelayOS pacman repositories (docs/packaging.md).
#
# Hosting: GitHub Releases of robiox-ui/delayos, one release per repository:
#   [delayos] -> tag repo-delayos, [delayos-v3] -> repo-delayos-v3, [delayos-v4], [delayos-znver4]
# Assets of a release: <pkg>.pkg.tar.zst, <pkg>.pkg.tar.zst.sig, <repo>.db(.sig), <repo>.files(.sig).
# pacman reads them with  Server = https://github.com/robiox-ui/delayos/releases/download/repo-$repo
#
#   DELAYOS_REPO_KEY=/root/delayos-keys/repo/delayos-repo-signing.asc \
#   GITHUB_TOKEN=<token with "contents: write" on robiox-ui/delayos> \
#   tools/repo-publish.sh [--level L[,L]|all] [--sign-only] [--dry-run] [--keep-old]
#
#   tools/repo-publish.sh --pull [--level ...]   fetch the published databases into an empty pool
#                                                (no token needed; CI runners start without a pool)
#
# The key and the token are read from the environment at run time and are never written anywhere:
# the key is imported into a GnuPG home on tmpfs that is deleted when the script ends.
# DELAYOS_REPO_KEY is a file path; DELAYOS_REPO_KEY_DATA may hold the armored key itself (CI secret).
#
# Order of an upload: packages and signatures first, the database last, then assets the database no
# longer names are deleted. A client therefore never sees a database that points at a missing file.
# Limits of GitHub Releases: 2 GiB per asset (checked before anything is uploaded) and 1000 assets
# per release, i.e. about 490 packages per repository.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=tools/repo-common.sh
. "$HERE/repo-common.sh"

LEVELSEL=all; SIGN_ONLY=0; DRY=0; KEEP_OLD=0; PULL=0
while (( $# )); do
  case "$1" in
    --level) LEVELSEL=${2:?}; shift ;;
    --level=*) LEVELSEL=${1#*=} ;;
    --sign-only) SIGN_ONLY=1 ;;
    --dry-run) DRY=1 ;;
    --keep-old) KEEP_OLD=1 ;;
    --pull) PULL=1 ;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option $1" ;;
  esac
  shift
done

API="https://api.github.com/repos/$GH_OWNER/$GH_REPO"
UPLOAD="https://uploads.github.com/repos/$GH_OWNER/$GH_REPO"
DOWNLOAD="https://github.com/$GH_OWNER/$GH_REPO/releases/download"
MAX_ASSET=$(( 2 * 1024 * 1024 * 1024 ))
TMP=$(mktemp -d)
GPGDIR=""
cleanup() {
  if [[ -n $GPGDIR && -d $GPGDIR ]]; then
    gpgconf --homedir "$GPGDIR" --kill all >/dev/null 2>&1 || true
    find "$GPGDIR" -type f -exec shred -u {} + 2>/dev/null || true
    rm -rf "${GPGDIR:?}"
  fi
  rm -rf "${TMP:?}"
}
trap cleanup EXIT

# ------------------------------------------------------------------ pull
pull_level() { # databases (and the content hash list) of a published repository -> local pool
  local level=$1 d name f
  d=$(pool_dir "$level"); name=$(repo_name "$level"); mkdir -p "$d"
  if pool_has_packages "$level"; then log "[$name] the local pool already has a database: left alone"; return 0; fi
  for f in "$name.db" "$name.files" content-hashes.txt; do
    if curl -fsSL --retry 3 -o "$TMP/$f" "$DOWNLOAD/$(release_tag "$level")/$f" 2>/dev/null; then
      case "$f" in
        *.db)    cp "$TMP/$f" "$d/$name.db.tar.gz"; ln -sf "$name.db.tar.gz" "$d/$name.db" ;;
        *.files) cp "$TMP/$f" "$d/$name.files.tar.gz"; ln -sf "$name.files.tar.gz" "$d/$name.files" ;;
        *)       [[ $level == generic ]] && cp "$TMP/$f" "$d/$f" ;;
      esac
    fi
  done
  if [[ -f $d/$name.db.tar.gz ]]; then log "[$name] pulled: $(db_list "$d/$name.db.tar.gz" | wc -l) packages published"
  else log "[$name] nothing published yet"; fi
}

if (( PULL )); then
  for l in $(expand_levels "$LEVELSEL"); do pull_level "$l"; done
  exit 0
fi

# ------------------------------------------------------------------ signing key
KEYFPR=""
load_key() {
  local trusted="$REPO_ROOT/packages/delayos-keyring/delayos-trusted" want base
  [[ -n ${DELAYOS_REPO_KEY:-} || -n ${DELAYOS_REPO_KEY_DATA:-} ]] \
    || die "Set DELAYOS_REPO_KEY to the signing key file (delayos-repo-signing.asc from tools/make-delayos-repo-key.sh)"
  case "$(realpath -m "${DELAYOS_REPO_KEY:-/nonexistent}")/" in
    "$REPO_ROOT"/*) die "The signing key is inside the repository. Move it out (and make sure it was never committed)." ;;
  esac
  [[ -s $trusted ]] || die "packages/delayos-keyring/delayos-trusted is missing: run tools/make-delayos-repo-key.sh"
  want=$(tr -d '\r' < "$trusted" | cut -d: -f1 | head -n1)
  base=/dev/shm; [[ -d $base && -w $base ]] || base=${TMPDIR:-/tmp}
  GPGDIR=$(mktemp -d "$base/delayos-gpg.XXXXXX"); chmod 700 "$GPGDIR"
  export GNUPGHOME="$GPGDIR"
  if [[ -n ${DELAYOS_REPO_KEY_DATA:-} ]]; then
    gpg --batch --quiet --import <<<"$DELAYOS_REPO_KEY_DATA" 2>/dev/null || die "cannot import DELAYOS_REPO_KEY_DATA"
  else
    [[ -r $DELAYOS_REPO_KEY ]] || die "cannot read $DELAYOS_REPO_KEY"
    gpg --batch --quiet --import "$DELAYOS_REPO_KEY" 2>/dev/null || die "cannot import $DELAYOS_REPO_KEY"
  fi
  KEYFPR=$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1=="fpr" && !d {print $10; d=1}')
  # the key must be the one the delayos-keyring package tells user PCs to trust
  [[ $KEYFPR == "$want" ]] || die "The signing key ($KEYFPR) is not the key of packages/delayos-keyring ($want)"
  echo test | gpg --batch --quiet --pinentry-mode loopback --passphrase "${DELAYOS_REPO_KEY_PASSPHRASE:-}" \
      -u "$KEYFPR" --detach-sign -o "$TMP/probe.sig" 2>/dev/null \
    || die "The key cannot sign (no usable signing subkey, expired, or a passphrase is needed: DELAYOS_REPO_KEY_PASSPHRASE)"
}

gpg_sign() { # $1 = file -> $1.sig
  local f=${1:?}
  rm -f "$f.sig"
  gpg --batch --quiet --pinentry-mode loopback --passphrase "${DELAYOS_REPO_KEY_PASSPHRASE:-}" \
      -u "$KEYFPR" --detach-sign --no-armor -o "$f.sig" "$f"
}

sign_level() {
  local level=$1 d name db n v f signed=0 line
  d=$(pool_dir "$level"); name=$(repo_name "$level"); db=$(db_file "$level")
  mapfile -t LIST < <(db_list "$db")
  for line in "${LIST[@]}"; do
    read -r n v f <<<"$line"
    # published earlier and not in this pool (pulled database): its signature is already online
    [[ -f $d/$f ]] || continue
    (( $(stat -c %s "$d/$f") < MAX_ASSET )) || die "$f is larger than 2 GiB: GitHub Releases cannot host it (split the package)"
    if [[ ! -f $d/$f.sig ]] || ! gpg --batch --quiet --verify "$d/$f.sig" "$d/$f" 2>/dev/null; then
      gpg_sign "$d/$f"; signed=$((signed + 1))
    fi
  done
  gpg_sign "$db"
  gpg_sign "$d/$name.files.tar.gz"
  log "[$name] ${#LIST[@]} packages in the database, $signed newly signed"
}

# Secure Boot: a published linux-delayos must come with the delayos-sb-general made from it
check_sb_pair() {
  local kv sv dep d f
  d=$(pool_dir generic)
  kv=$(pool_version generic linux-delayos); sv=$(pool_version generic delayos-sb-general)
  [[ -n $kv && -n $sv ]] || return 0
  f=$(db_list "$(db_file generic)" | awk '$1=="delayos-sb-general"{print $3}')
  [[ -f $d/$f ]] || { warn "delayos-sb-general is published but not in this pool: cannot check it against linux-delayos $kv"; return 0; }
  dep=$(pkg_field "$d/$f" depend | sed -n 's/^linux-delayos=//p')
  [[ -z $dep || $dep == "$kv" ]] || die "delayos-sb-general $sv was made for linux-delayos $dep, the pool has $kv. Rebuild it (tools/repo-build.sh kernel with the general Secure Boot keys): PCs with Secure Boot on could not boot the new kernel."
}

# ------------------------------------------------------------------ GitHub
gh() { # method url [curl args...]  -> body in $TMP/resp, prints the HTTP status
  local method=$1 url=$2; shift 2
  curl -sS -o "$TMP/resp" -w '%{http_code}' -X "$method" \
    -H "Authorization: Bearer $GITHUB_TOKEN" -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' "$@" "$url"
}

release_id() { # $1 = level -> id (creates the release when it does not exist)
  local tag code; tag=$(release_tag "$1")
  code=$(gh GET "$API/releases/tags/$tag")
  if [[ $code == 404 ]]; then
    printf '{"tag_name":"%s","name":"pacman repository [%s]","body":"Package repository of DelayOS. Not a download for people: pacman reads it (docs/packaging.md).","make_latest":"false"}' \
      "$tag" "$(repo_name "$1")" > "$TMP/req"
    code=$(gh POST "$API/releases" -H 'Content-Type: application/json' --data-binary "@$TMP/req")
    [[ $code == 201 ]] || die "cannot create the release $tag (HTTP $code): $(head -c 300 "$TMP/resp")"
  elif [[ $code != 200 ]]; then
    die "cannot read the release $tag (HTTP $code): $(head -c 300 "$TMP/resp")"
  fi
  # the release object starts with its own urls and id; "id" of the author comes later
  tr -d '\n' < "$TMP/resp" | sed -E 's/.*"upload_url": *"[^"]*\/releases\/([0-9]+)\/assets.*/\1/'
}

# "id size name" of every asset of a release -> $TMP/assets
list_assets() { # $1 = release id
  local page=1 code obj cnt
  : > "$TMP/assets"
  while :; do
    code=$(gh GET "$API/releases/$1/assets?per_page=100&page=$page")
    [[ $code == 200 ]] || die "cannot list the assets (HTTP $code)"
    # one asset object per line; every asset object starts with its own "url": ".../releases/assets/<id>"
    tr -d '\n' < "$TMP/resp" | sed 's/{ *"url": *"[^"]*\/releases\/assets\//\n&/g' > "$TMP/page"
    cnt=0
    while IFS= read -r obj || [[ -n $obj ]]; do
      [[ $obj == *'/releases/assets/'* ]] || continue
      cnt=$((cnt + 1))
      printf '%s %s %s\n' \
        "$(sed -E 's/^[^"]*"url": *"[^"]*\/releases\/assets\/([0-9]+)".*/\1/' <<<"$obj")" \
        "$(sed -E 's/.*"size": *([0-9]+).*/\1/' <<<"$obj")" \
        "$(sed -E 's/^[^"]*"url": *"[^"]*"[^{]*"name": *"([^"]+)".*/\1/' <<<"$obj")" >> "$TMP/assets"
    done < "$TMP/page"
    (( cnt == 100 )) || break
    page=$((page + 1))
  done
}

upload_asset() { # $1 = release id, $2 = file, $3 = asset name ; replaces an asset of the same name
  local rid=$1 file=$2 name=$3 old code got
  old=$(awk -v n="$name" '$3==n{print $1}' "$TMP/assets")
  if [[ -n $old ]]; then
    code=$(gh DELETE "$API/releases/assets/$old"); [[ $code == 204 ]] || die "cannot replace $name (HTTP $code)"
  fi
  code=$(gh POST "$UPLOAD/releases/$rid/assets?name=$name" -H 'Content-Type: application/octet-stream' --data-binary "@$file" --retry 3)
  [[ $code == 201 ]] || die "upload of $name failed (HTTP $code): $(head -c 300 "$TMP/resp")"
  got=$(tr -d '\n' < "$TMP/resp" | sed -E 's/^[^"]*"url": *"[^"]*"[^{]*"name": *"([^"]+)".*/\1/')
  [[ $got == "$name" ]] || die "GitHub stored $name as '$got': pacman would not find it"
}

publish_level() {
  local level=$1 d name rid n v f a up=0 skip=0 keep line id size aname
  d=$(pool_dir "$level"); name=$(repo_name "$level")
  mapfile -t LIST < <(db_list "$(db_file "$level")")
  (( ${#LIST[@]} )) || { log "[$name] empty: nothing to publish"; return 0; }
  if (( DRY )); then
    log "[$name] would publish ${#LIST[@]} packages to the release $(release_tag "$level"):"
    for line in "${LIST[@]}"; do
      read -r n v f <<<"$line"
      if [[ -f $d/$f ]]; then printf '    %-34s %-24s %s\n' "$n" "$v" "$(du -h "$d/$f" | cut -f1)"
      else printf '    %-34s %-24s (already online)\n' "$n" "$v"; fi
    done
    return 0
  fi
  rid=$(release_id "$level")
  [[ $rid =~ ^[0-9]+$ ]] || die "cannot read the id of the release $(release_tag "$level")"
  list_assets "$rid"
  keep="$TMP/keep"; printf '%s\n' "$name.db" "$name.db.sig" "$name.files" "$name.files.sig" > "$keep"
  [[ $level == generic ]] && echo content-hashes.txt >> "$keep"
  for line in "${LIST[@]}"; do
    read -r n v f <<<"$line"
    printf '%s\n%s.sig\n' "$f" "$f" >> "$keep"
    [[ -f $d/$f ]] || continue
    # same name and size as online: this build is already there (the file name carries the version)
    if [[ $(awk -v n="$f" '$3==n{print $2}' "$TMP/assets") == "$(stat -c %s "$d/$f")" ]] &&
       [[ -n $(awk -v n="$f.sig" '$3==n{print $1}' "$TMP/assets") ]]; then
      skip=$((skip + 1)); continue
    fi
    for a in "$f" "$f.sig"; do upload_asset "$rid" "$d/$a" "$a"; up=$((up + 1)); done
  done
  # the database last
  upload_asset "$rid" "$(db_file "$level")" "$name.db"
  upload_asset "$rid" "$(db_file "$level").sig" "$name.db.sig"
  upload_asset "$rid" "$d/$name.files.tar.gz" "$name.files"
  upload_asset "$rid" "$d/$name.files.tar.gz.sig" "$name.files.sig"
  if [[ $level == generic && -f $d/content-hashes.txt ]]; then upload_asset "$rid" "$d/content-hashes.txt" content-hashes.txt; fi
  # what the database no longer names
  if (( ! KEEP_OLD )); then
    while read -r id size aname; do
      grep -qxF "$aname" "$keep" && continue
      gh DELETE "$API/releases/assets/$id" >/dev/null && log "[$name] removed old asset $aname"
    done < "$TMP/assets"
  fi
  log "[$name] published: $up files uploaded, $skip packages already online"
  (( $(wc -l < "$keep") <= 1000 )) || warn "[$name] more than 1000 assets: GitHub Releases will refuse further uploads"
}

# ------------------------------------------------------------------ main
command -v gpg >/dev/null || die "gnupg is missing"
levels=$(expand_levels "$LEVELSEL")
if (( DRY )) && [[ -z ${DELAYOS_REPO_KEY:-}${DELAYOS_REPO_KEY_DATA:-} ]]; then
  for l in $levels; do publish_level "$l"; done
  exit 0
fi
load_key
check_sb_pair
for l in $levels; do
  pool_has_packages "$l" || continue
  sign_level "$l"
done
if (( SIGN_ONLY )); then log "Signed. Not uploaded (--sign-only)."; exit 0; fi
(( DRY )) || [[ -n ${GITHUB_TOKEN:-} ]] || die "Set GITHUB_TOKEN (fine-grained token, Contents: read and write on $GH_OWNER/$GH_REPO)"
for l in $levels; do publish_level "$l"; done
log "Done. Clients: Server = $DOWNLOAD/repo-\$repo"
