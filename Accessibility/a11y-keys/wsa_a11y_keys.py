#!/usr/bin/env python3
"""WSA: let accessibility services (TalkBack, Jieshuo, ...) receive every key typed in Windows.

WSA delivers most Windows keys to Android with InputManager.injectInputEvent() (from
com.microsoft.windows.userapp). Injected events skip the input filter, so screen readers only
see modifiers and some Alt combinations. This patches services.jar so that, while an input
filter is installed, key events injected by WSA go through it like hardware keys
(see WsaA11yKeyRouter.java). Nothing else changes.

  wsa_a11y_keys.py --system MOUNTED_SYSTEM_DIR     patch <dir>/framework/services.jar in place
                                                   (keeps owner, mode, SELinux label) and remove
                                                   its stale <dir>/framework/oat/*/services.*
  wsa_a11y_keys.py --jar services.jar --out new.jar
  wsa_a11y_keys.py --jar services.jar --check      only report what would happen

Tools: java, plus the smali and baksmali 2.5.x release jars (smali-2.5.2.jar, baksmali-2.5.2.jar),
given with --smali/--baksmali or $SMALI_JAR/$BAKSMALI_JAR. Python 3.8+, stdlib only.
Exit codes: 0 patched or already patched, 2 not applicable (nothing written), 1 error.
"""
import argparse
import glob
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER_SMALI = os.path.join(HERE, "WsaA11yKeyRouter.smali")
IMS_CLASS = "Lcom/android/server/input/InputManagerService;"
HELPER_CLASS = "Lcom/android/server/input/WsaA11yKeyRouter;"
TARGET_METHOD = ".method public injectInputEventToTarget(Landroid/view/InputEvent;II)Z"
# p0 = this, p1 = event, p2 = mode, p3 = targetUid
TARGET_PARAM_REGS = 4
REQUIRED_MEMBERS = [
    ".field private final mContext:Landroid/content/Context;",
    ".field mInputFilter:Landroid/view/IInputFilter;",
    ".method private interceptKeyBeforeQueueing(Landroid/view/KeyEvent;I)I",
    ".method final filterInputEvent(Landroid/view/InputEvent;I)Z",
]
HOOK = """
    # WSA: key events injected by WSA go through the accessibility input filter
    invoke-static/range {p0 .. p3}, Lcom/android/server/input/WsaA11yKeyRouter;->route(Ljava/lang/Object;Landroid/view/InputEvent;II)Z

    move-result v0

    if-eqz v0, :wsa_a11y_inject_normally

    const/4 v0, 0x1

    return v0

    :wsa_a11y_inject_normally
"""
MAX_METHOD_REFS = 65535


class NotApplicable(Exception):
    pass


# ---------------------------------------------------------------- dex helpers

def _uleb128(data, off):
    result = shift = 0
    while True:
        b = data[off]
        off += 1
        result |= (b & 0x7F) << shift
        if b < 0x80:
            return result, off
        shift += 7


def dex_class_names(data):
    """Descriptors of the classes defined in a dex file."""
    if data[:4] != b"dex\n":
        raise ValueError("not a dex file")
    string_ids_off = struct.unpack_from("<I", data, 0x3C)[0]
    type_ids_off = struct.unpack_from("<I", data, 0x44)[0]
    class_defs_size, class_defs_off = struct.unpack_from("<II", data, 0x60)
    names = set()
    for i in range(class_defs_size):
        class_idx = struct.unpack_from("<I", data, class_defs_off + 32 * i)[0]
        string_idx = struct.unpack_from("<I", data, type_ids_off + 4 * class_idx)[0]
        str_off = struct.unpack_from("<I", data, string_ids_off + 4 * string_idx)[0]
        _, start = _uleb128(data, str_off)
        names.add(data[start:data.index(b"\0", start)].decode("utf-8", "replace"))
    return names


def dex_method_refs(data):
    return struct.unpack_from("<I", data, 0x58)[0]


def dex_entries(jar):
    names = [n for n in jar.namelist() if re.fullmatch(r"classes\d*\.dex", n)]
    return sorted(names, key=lambda n: int(n[7:-4] or 1))


# ---------------------------------------------------------------- smali tools

class Smali:
    def __init__(self, smali_jar, baksmali_jar, java, api):
        for name, jar in (("smali", smali_jar), ("baksmali", baksmali_jar)):
            if not jar or not os.path.isfile(jar):
                raise SystemExit("%s jar missing: use --%s or $%s_JAR" % (name, name, name.upper()))
        self.smali, self.baksmali, self.java, self.api = smali_jar, baksmali_jar, java, str(api)

    def _run(self, jar, args):
        # each release jar bundles its own shrunk dependencies: never share a classpath
        cmd = [self.java, "-Xmx4g", "-jar", jar] + args
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if r.returncode != 0:
            raise SystemExit("%s failed:\n%s" % (os.path.basename(jar), r.stdout[-3000:]))

    def disassemble(self, dex, out_dir):
        self._run(self.baksmali, ["d", dex, "--api", self.api, "-o", out_dir])

    def assemble(self, src_dir, out_dex):
        # one job: parallel assembly orders class_defs by completion, so output would vary per run
        self._run(self.smali, ["a", src_dir, "--api", self.api, "-j", "1", "-o", out_dex])


# ---------------------------------------------------------------- patch logic

def patch_ims_smali(text):
    """Insert the hook at the top of injectInputEventToTarget. Returns the new text."""
    missing = [m for m in REQUIRED_MEMBERS + [TARGET_METHOD] if m not in text]
    if missing:
        raise NotApplicable("InputManagerService lacks: " + "; ".join(missing))
    start = text.index(TARGET_METHOD)
    end = text.index(".end method", start)
    body = text[start:end].split("\n")
    reg_line = next((i for i, l in enumerate(body) if l.strip().startswith(".registers ")), None)
    if reg_line is None:
        raise NotApplicable("injectInputEventToTarget has no .registers directive")
    registers = int(body[reg_line].split()[1])
    if registers - TARGET_PARAM_REGS < 1:
        body[reg_line] = "    .registers %d" % (TARGET_PARAM_REGS + 1)
    # first line after the .param / .annotation blocks that open the method
    i, depth = reg_line + 1, 0
    while i < len(body):
        s = body[i].strip()
        if s.startswith(".annotation"):
            depth += 1
        elif s == ".end annotation":
            depth -= 1
        elif depth == 0 and s and not s.startswith(".param") and s != ".end param":
            break
        i += 1
    body[i:i] = HOOK.split("\n")
    return text[:start] + "\n".join(body) + text[end:]


def build_jar(orig_jar, out_jar, replace):
    """Rewrite a jar keeping entry order, compression and dates; stored entries 4-byte aligned."""
    zin = zipfile.ZipFile(orig_jar)
    entries = []
    for info in zin.infolist():
        payload = replace.pop(info.filename) if info.filename in replace else zin.read(info)
        entries.append((info.filename, payload, info.compress_type, info.date_time, info.external_attr))
    zin.close()
    for name, payload in replace.items():
        entries.append((name, payload, zipfile.ZIP_STORED, (2008, 1, 1, 0, 0, 0), 0))
    body, cd = bytearray(), bytearray()
    for name, payload, method, dt, ext_attr in entries:
        fname = name.encode()
        crc = zlib.crc32(payload) & 0xFFFFFFFF
        if method == zipfile.ZIP_STORED:
            comp = payload
        else:
            co = zlib.compressobj(9, zlib.DEFLATED, -15)
            comp = co.compress(payload) + co.flush()
            method = zipfile.ZIP_DEFLATED
        dosdate = (dt[0] - 1980) << 9 | dt[1] << 5 | dt[2]
        dostime = dt[3] << 11 | dt[4] << 5 | dt[5] // 2
        off = len(body)
        extra = b"\0" * ((-(off + 30 + len(fname))) % 4) if method == zipfile.ZIP_STORED else b""
        flags = 0x800 if any(b > 127 for b in fname) else 0
        body += struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, flags, method, dostime, dosdate,
                            crc, len(comp), len(payload), len(fname), len(extra))
        body += fname + extra + comp
        cd += struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 20, 20, flags, method, dostime, dosdate,
                          crc, len(comp), len(payload), len(fname), 0, 0, 0, 0, ext_attr, off)
        cd += fname
    eocd = struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, len(entries), len(entries), len(cd), len(body), 0)
    with open(out_jar, "wb") as o:
        o.write(body + cd + eocd)


def patch_jar(jar_path, out_path, smali, check_only=False):
    """Returns 'patched' or 'already patched'; raises NotApplicable when the jar doesn't fit."""
    with zipfile.ZipFile(jar_path) as jar:
        dexes = dex_entries(jar)
        if not dexes:
            raise NotApplicable("no classes.dex in " + jar_path)
        owner = None
        for name in dexes:
            classes = dex_class_names(jar.read(name))
            if HELPER_CLASS in classes:
                return "already patched"
            if IMS_CLASS in classes:
                owner = name
        if owner is None:
            raise NotApplicable("InputManagerService not found in " + jar_path)
        owner_data = jar.read(owner)
    if dex_method_refs(owner_data) + 1 > MAX_METHOD_REFS:
        raise NotApplicable("%s has no room for one more method reference" % owner)
    new_dex_name = "classes%d.dex" % (len(dexes) + 1)

    work = tempfile.mkdtemp(prefix="wsa_a11y_")
    try:
        with open(os.path.join(work, "owner.dex"), "wb") as f:
            f.write(owner_data)
        smali.disassemble(os.path.join(work, "owner.dex"), os.path.join(work, "owner"))
        ims_path = os.path.join(work, "owner", "com", "android", "server", "input",
                                "InputManagerService.smali")
        with open(ims_path, encoding="utf-8") as f:
            patched = patch_ims_smali(f.read())
        if check_only:
            return "patchable (%s, InputManagerService in %s, helper -> %s)" % (
                os.path.basename(jar_path), owner, new_dex_name)
        with open(ims_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(patched)
        smali.assemble(os.path.join(work, "owner"), os.path.join(work, "owner.new.dex"))
        helper_src = os.path.join(work, "helper", "com", "android", "server", "input")
        os.makedirs(helper_src)
        shutil.copy(HELPER_SMALI, helper_src)
        smali.assemble(os.path.join(work, "helper"), os.path.join(work, "helper.dex"))
        with open(os.path.join(work, "owner.new.dex"), "rb") as f:
            new_owner = f.read()
        with open(os.path.join(work, "helper.dex"), "rb") as f:
            helper = f.read()
        if IMS_CLASS not in dex_class_names(new_owner) or HELPER_CLASS not in dex_class_names(helper):
            raise SystemExit("reassembled dex files are incomplete")
        build_jar(jar_path, out_path, {owner: new_owner, new_dex_name: helper})
        return "patched (%s rebuilt, helper in %s)" % (owner, new_dex_name)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def patch_system_dir(system_dir, smali, check_only):
    jar = os.path.join(system_dir, "framework", "services.jar")
    if not os.path.isfile(jar):
        raise NotApplicable("missing " + jar)
    fd, tmp = tempfile.mkstemp(prefix="services_", suffix=".jar")  # outside the image
    os.close(fd)
    try:
        result = patch_jar(jar, tmp, smali, check_only)
        if result.startswith("patched"):
            # rewrite the existing inode: keeps owner, mode and the security.selinux label
            with open(tmp, "rb") as src, open(jar, "r+b") as dst:
                dst.truncate(0)
                shutil.copyfileobj(src, dst)
            stale = glob.glob(os.path.join(system_dir, "framework", "oat", "*", "services.*"))
            for f in stale:
                os.remove(f)
            result += "; removed %d stale oat files" % len(stale)
        return result
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--system", help="mounted system directory (contains framework/services.jar)")
    g.add_argument("--jar", help="services.jar to patch")
    ap.add_argument("--out", help="output jar (with --jar)")
    ap.add_argument("--check", action="store_true", help="report only, write nothing")
    ap.add_argument("--smali", default=os.environ.get("SMALI_JAR"),
                    help="smali 2.5.x jar (default: $SMALI_JAR)")
    ap.add_argument("--baksmali", default=os.environ.get("BAKSMALI_JAR"),
                    help="baksmali 2.5.x jar (default: $BAKSMALI_JAR)")
    ap.add_argument("--java", default=os.environ.get("JAVA", "java"))
    ap.add_argument("--api", type=int, default=33, help="Android API level (WSA 2407: 33)")
    a = ap.parse_args()
    if a.jar and not (a.out or a.check):
        ap.error("--jar needs --out or --check")
    smali = Smali(a.smali, a.baksmali, a.java, a.api)
    try:
        if a.system:
            print(patch_system_dir(a.system, smali, a.check))
        else:
            print(patch_jar(a.jar, a.out, smali, a.check))
    except NotApplicable as e:
        print("not applicable, nothing written: %s" % e, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
