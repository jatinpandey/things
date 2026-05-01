#!/usr/bin/env python3
"""Generate Things.xcodeproj/project.pbxproj for the SwiftUI Things app.

Single-target iOS 17+ SwiftUI app, sources auto-discovered under Things/.
"""
from __future__ import annotations
import hashlib
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_DIR = ROOT / "Things"
PROJ_DIR = ROOT / "Things.xcodeproj"
PROJ_DIR.mkdir(exist_ok=True)

BUNDLE_ID = "com.example.Things"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.9"
DEVELOPMENT_TEAM = ""  # leave empty; sign manually in Xcode if needed


def uid(*parts: str) -> str:
    h = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest().upper()
    return h[:24]


def discover_sources() -> list[Path]:
    out = []
    for p in sorted(APP_DIR.rglob("*.swift")):
        out.append(p.relative_to(ROOT))
    return out


def discover_resources() -> list[Path]:
    out = []
    # Assets.xcassets folder reference
    assets = APP_DIR / "Assets.xcassets"
    if assets.exists():
        out.append(assets.relative_to(ROOT))
    preview = APP_DIR / "Preview Content"
    if preview.exists():
        out.append(preview.relative_to(ROOT))
    return out


def file_type(name: str) -> str:
    if name.endswith(".swift"):
        return "sourcecode.swift"
    if name.endswith(".xcassets"):
        return "folder.assetcatalog"
    if name.endswith(".plist"):
        return "text.plist.xml"
    return "folder"


def build_pbxproj() -> str:
    sources = discover_sources()
    resources = discover_resources()

    # IDs
    proj_id           = uid("project")
    main_group_id     = uid("group", "main")
    products_group_id = uid("group", "products")
    things_group_id   = uid("group", "Things")
    target_id         = uid("target", "Things")
    product_ref_id    = uid("product", "Things.app")
    sources_phase_id  = uid("phase", "sources")
    resources_phase_id = uid("phase", "resources")
    frameworks_phase_id = uid("phase", "frameworks")
    proj_cfg_list_id  = uid("cfglist", "project")
    target_cfg_list_id = uid("cfglist", "target")
    proj_debug_id     = uid("cfg", "project", "Debug")
    proj_release_id   = uid("cfg", "project", "Release")
    target_debug_id   = uid("cfg", "target", "Debug")
    target_release_id = uid("cfg", "target", "Release")

    # File refs + build files
    file_refs: list[tuple[str, str, str]] = []  # (id, name, type)
    build_files_sources: list[tuple[str, str, str]] = []  # (build_id, file_id, name)
    build_files_resources: list[tuple[str, str, str]] = []

    # Track per-folder groups under Things/
    folder_groups: dict[str, str] = {"": things_group_id}
    folder_children: dict[str, list[str]] = {"": []}

    def ensure_folder_group(rel_dir: str) -> str:
        # rel_dir is relative to Things/, "" = root
        if rel_dir in folder_groups:
            return folder_groups[rel_dir]
        gid = uid("group", "Things", rel_dir)
        folder_groups[rel_dir] = gid
        folder_children[rel_dir] = []
        # parent
        parent = "/".join(rel_dir.split("/")[:-1])
        ensure_folder_group(parent)
        folder_children[parent].append(gid)
        return gid

    # Source file refs grouped by their subdirectory under Things/
    for src in sources:
        # path relative to project root, e.g. "Things/Views/ListView.swift"
        rel_to_things = src.relative_to("Things")
        sub_dir = str(rel_to_things.parent) if str(rel_to_things.parent) != "." else ""
        gid = ensure_folder_group(sub_dir)

        fid = uid("file", str(src))
        bid = uid("buildfile", "src", str(src))
        file_refs.append((fid, src.name, file_type(src.name)))
        build_files_sources.append((bid, fid, src.name))
        folder_children[sub_dir].append(fid)

    # Resource file refs (placed at Things group root)
    for res in resources:
        fid = uid("file", str(res))
        bid = uid("buildfile", "res", str(res))
        file_refs.append((fid, res.name, file_type(res.name)))
        build_files_resources.append((bid, fid, res.name))
        folder_children[""].append(fid)

    # Compose pbxproj text
    L: list[str] = []
    L.append("// !$*UTF8*$!")
    L.append("{")
    L.append("\tarchiveVersion = 1;")
    L.append("\tclasses = {};")
    L.append("\tobjectVersion = 56;")
    L.append("\tobjects = {")

    # PBXBuildFile
    L.append("")
    L.append("/* Begin PBXBuildFile section */")
    for bid, fid, name in build_files_sources:
        L.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
    for bid, fid, name in build_files_resources:
        L.append(f"\t\t{bid} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
    L.append("/* End PBXBuildFile section */")

    # PBXFileReference
    L.append("")
    L.append("/* Begin PBXFileReference section */")
    L.append(f"\t\t{product_ref_id} /* Things.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Things.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    # Source/resource refs — paths relative to their group; we'll store path = filename and group has its own path.
    # To keep things simple, we set each fileRef's path to its filename; the group sets the directory path.
    # Build a map of file id -> (name, type, full relative path)
    src_meta: dict[str, tuple[str, str, str]] = {}
    for src in sources:
        fid = uid("file", str(src))
        src_meta[fid] = (src.name, file_type(src.name), str(src))
    for res in resources:
        fid = uid("file", str(res))
        src_meta[fid] = (res.name, file_type(res.name), str(res))

    for fid, (name, ftype, _path) in src_meta.items():
        if name == "Preview Content":
            L.append(f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = folder; path = "{name}"; sourceTree = "<group>"; }};')
        else:
            L.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = \"{name}\"; sourceTree = \"<group>\"; }};")
    L.append("/* End PBXFileReference section */")

    # PBXFrameworksBuildPhase
    L.append("")
    L.append("/* Begin PBXFrameworksBuildPhase section */")
    L.append(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
    L.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    L.append("\t\t\tbuildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    L.append("\t\t\t);")
    L.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXFrameworksBuildPhase section */")

    # PBXGroup
    L.append("")
    L.append("/* Begin PBXGroup section */")
    # Main group
    L.append(f"\t\t{main_group_id} = {{")
    L.append("\t\t\tisa = PBXGroup;")
    L.append("\t\t\tchildren = (")
    L.append(f"\t\t\t\t{things_group_id} /* Things */,")
    L.append(f"\t\t\t\t{products_group_id} /* Products */,")
    L.append("\t\t\t);")
    L.append("\t\t\tsourceTree = \"<group>\";")
    L.append("\t\t};")
    # Products group
    L.append(f"\t\t{products_group_id} /* Products */ = {{")
    L.append("\t\t\tisa = PBXGroup;")
    L.append("\t\t\tchildren = (")
    L.append(f"\t\t\t\t{product_ref_id} /* Things.app */,")
    L.append("\t\t\t);")
    L.append("\t\t\tname = Products;")
    L.append("\t\t\tsourceTree = \"<group>\";")
    L.append("\t\t};")

    # Things groups (root + nested)
    for rel_dir, gid in folder_groups.items():
        children = folder_children.get(rel_dir, [])
        if rel_dir == "":
            name = "Things"
            path = "Things"
        else:
            name = rel_dir.split("/")[-1]
            path = name
        L.append(f"\t\t{gid} /* {name} */ = {{")
        L.append("\t\t\tisa = PBXGroup;")
        L.append("\t\t\tchildren = (")
        for cid in children:
            # Look up display name
            disp = "?"
            if cid in src_meta:
                disp = src_meta[cid][0]
            else:
                # nested folder group
                for rd, g in folder_groups.items():
                    if g == cid:
                        disp = rd.split("/")[-1] or rd
                        break
            L.append(f"\t\t\t\t{cid} /* {disp} */,")
        L.append("\t\t\t);")
        L.append(f"\t\t\tpath = \"{path}\";")
        L.append("\t\t\tsourceTree = \"<group>\";")
        L.append("\t\t};")
    L.append("/* End PBXGroup section */")

    # PBXNativeTarget
    L.append("")
    L.append("/* Begin PBXNativeTarget section */")
    L.append(f"\t\t{target_id} /* Things */ = {{")
    L.append("\t\t\tisa = PBXNativeTarget;")
    L.append(f"\t\t\tbuildConfigurationList = {target_cfg_list_id} /* Build configuration list for PBXNativeTarget \"Things\" */;")
    L.append("\t\t\tbuildPhases = (")
    L.append(f"\t\t\t\t{sources_phase_id} /* Sources */,")
    L.append(f"\t\t\t\t{frameworks_phase_id} /* Frameworks */,")
    L.append(f"\t\t\t\t{resources_phase_id} /* Resources */,")
    L.append("\t\t\t);")
    L.append("\t\t\tbuildRules = (")
    L.append("\t\t\t);")
    L.append("\t\t\tdependencies = (")
    L.append("\t\t\t);")
    L.append("\t\t\tname = Things;")
    L.append("\t\t\tproductName = Things;")
    L.append(f"\t\t\tproductReference = {product_ref_id} /* Things.app */;")
    L.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    L.append("\t\t};")
    L.append("/* End PBXNativeTarget section */")

    # PBXProject
    L.append("")
    L.append("/* Begin PBXProject section */")
    L.append(f"\t\t{proj_id} /* Project object */ = {{")
    L.append("\t\t\tisa = PBXProject;")
    L.append("\t\t\tattributes = {")
    L.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    L.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    L.append("\t\t\t\tLastUpgradeCheck = 1500;")
    L.append("\t\t\t\tTargetAttributes = {")
    L.append(f"\t\t\t\t\t{target_id} = {{")
    L.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    L.append("\t\t\t\t\t};")
    L.append("\t\t\t\t};")
    L.append("\t\t\t};")
    L.append(f"\t\t\tbuildConfigurationList = {proj_cfg_list_id} /* Build configuration list for PBXProject \"Things\" */;")
    L.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    L.append("\t\t\tdevelopmentRegion = en;")
    L.append("\t\t\thasScannedForEncodings = 0;")
    L.append("\t\t\tknownRegions = (")
    L.append("\t\t\t\ten,")
    L.append("\t\t\t\tBase,")
    L.append("\t\t\t);")
    L.append(f"\t\t\tmainGroup = {main_group_id};")
    L.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    L.append("\t\t\tprojectDirPath = \"\";")
    L.append("\t\t\tprojectRoot = \"\";")
    L.append("\t\t\ttargets = (")
    L.append(f"\t\t\t\t{target_id} /* Things */,")
    L.append("\t\t\t);")
    L.append("\t\t};")
    L.append("/* End PBXProject section */")

    # PBXResourcesBuildPhase
    L.append("")
    L.append("/* Begin PBXResourcesBuildPhase section */")
    L.append(f"\t\t{resources_phase_id} /* Resources */ = {{")
    L.append("\t\t\tisa = PBXResourcesBuildPhase;")
    L.append("\t\t\tbuildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    for bid, _fid, name in build_files_resources:
        L.append(f"\t\t\t\t{bid} /* {name} in Resources */,")
    L.append("\t\t\t);")
    L.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXResourcesBuildPhase section */")

    # PBXSourcesBuildPhase
    L.append("")
    L.append("/* Begin PBXSourcesBuildPhase section */")
    L.append(f"\t\t{sources_phase_id} /* Sources */ = {{")
    L.append("\t\t\tisa = PBXSourcesBuildPhase;")
    L.append("\t\t\tbuildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    for bid, _fid, name in build_files_sources:
        L.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
    L.append("\t\t\t);")
    L.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXSourcesBuildPhase section */")

    # XCBuildConfiguration — project
    L.append("")
    L.append("/* Begin XCBuildConfiguration section */")
    proj_common = [
        "ALWAYS_SEARCH_USER_PATHS = NO;",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;",
        "CLANG_ANALYZER_NONNULL = YES;",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
        "CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";",
        "CLANG_ENABLE_MODULES = YES;",
        "CLANG_ENABLE_OBJC_ARC = YES;",
        "CLANG_ENABLE_OBJC_WEAK = YES;",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;",
        "CLANG_WARN_BOOL_CONVERSION = YES;",
        "CLANG_WARN_COMMA = YES;",
        "CLANG_WARN_CONSTANT_CONVERSION = YES;",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
        "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
        "CLANG_WARN_EMPTY_BODY = YES;",
        "CLANG_WARN_ENUM_CONVERSION = YES;",
        "CLANG_WARN_INFINITE_RECURSION = YES;",
        "CLANG_WARN_INT_CONVERSION = YES;",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
        "CLANG_WARN_STRICT_PROTOTYPES = YES;",
        "CLANG_WARN_SUSPICIOUS_MOVE = YES;",
        "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
        "CLANG_WARN_UNREACHABLE_CODE = YES;",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
        "COPY_PHASE_STRIP = NO;",
        "ENABLE_STRICT_OBJC_MSGSEND = YES;",
        "ENABLE_USER_SCRIPT_SANDBOXING = YES;",
        "GCC_C_LANGUAGE_STANDARD = gnu17;",
        "GCC_NO_COMMON_BLOCKS = YES;",
        "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
        "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
        "GCC_WARN_UNDECLARED_SELECTOR = YES;",
        "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
        "GCC_WARN_UNUSED_FUNCTION = YES;",
        "GCC_WARN_UNUSED_VARIABLE = YES;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;",
        "MTL_FAST_MATH = YES;",
        "SDKROOT = iphoneos;",
        f"SWIFT_VERSION = {SWIFT_VERSION};",
    ]
    proj_debug = proj_common + [
        "DEBUG_INFORMATION_FORMAT = dwarf;",
        "ENABLE_TESTABILITY = YES;",
        "GCC_DYNAMIC_NO_PIC = NO;",
        "GCC_OPTIMIZATION_LEVEL = 0;",
        "GCC_PREPROCESSOR_DEFINITIONS = (",
        "\t\"DEBUG=1\",",
        "\t\"$(inherited)\",",
        ");",
        "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;",
        "ONLY_ACTIVE_ARCH = YES;",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";",
        "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
    ]
    proj_release = proj_common + [
        "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
        "ENABLE_NS_ASSERTIONS = NO;",
        "MTL_ENABLE_DEBUG_INFO = NO;",
        "SWIFT_COMPILATION_MODE = wholemodule;",
        "VALIDATE_PRODUCT = YES;",
    ]
    L.append(f"\t\t{proj_debug_id} /* Debug */ = {{")
    L.append("\t\t\tisa = XCBuildConfiguration;")
    L.append("\t\t\tbuildSettings = {")
    for line in proj_debug:
        L.append(f"\t\t\t\t{line}")
    L.append("\t\t\t};")
    L.append("\t\t\tname = Debug;")
    L.append("\t\t};")
    L.append(f"\t\t{proj_release_id} /* Release */ = {{")
    L.append("\t\t\tisa = XCBuildConfiguration;")
    L.append("\t\t\tbuildSettings = {")
    for line in proj_release:
        L.append(f"\t\t\t\t{line}")
    L.append("\t\t\t};")
    L.append("\t\t\tname = Release;")
    L.append("\t\t};")

    # XCBuildConfiguration — target
    target_common = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
        "CODE_SIGN_STYLE = Automatic;",
        "CURRENT_PROJECT_VERSION = 1;",
        f"DEVELOPMENT_TEAM = \"{DEVELOPMENT_TEAM}\";",
        "DEVELOPMENT_ASSET_PATHS = \"\\\"Things/Preview Content\\\"\";",
        "ENABLE_PREVIEWS = YES;",
        "GENERATE_INFOPLIST_FILE = YES;",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;",
        "INFOPLIST_KEY_UILaunchScreen_Generation = YES;",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationPortrait\";",
        "LD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";",
        "MARKETING_VERSION = 1.0;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
        "PRODUCT_NAME = \"$(TARGET_NAME)\";",
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        "TARGETED_DEVICE_FAMILY = \"1,2\";",
    ]
    L.append(f"\t\t{target_debug_id} /* Debug */ = {{")
    L.append("\t\t\tisa = XCBuildConfiguration;")
    L.append("\t\t\tbuildSettings = {")
    for line in target_common:
        L.append(f"\t\t\t\t{line}")
    L.append("\t\t\t};")
    L.append("\t\t\tname = Debug;")
    L.append("\t\t};")
    L.append(f"\t\t{target_release_id} /* Release */ = {{")
    L.append("\t\t\tisa = XCBuildConfiguration;")
    L.append("\t\t\tbuildSettings = {")
    for line in target_common:
        L.append(f"\t\t\t\t{line}")
    L.append("\t\t\t};")
    L.append("\t\t\tname = Release;")
    L.append("\t\t};")
    L.append("/* End XCBuildConfiguration section */")

    # XCConfigurationList
    L.append("")
    L.append("/* Begin XCConfigurationList section */")
    L.append(f"\t\t{proj_cfg_list_id} /* Build configuration list for PBXProject \"Things\" */ = {{")
    L.append("\t\t\tisa = XCConfigurationList;")
    L.append("\t\t\tbuildConfigurations = (")
    L.append(f"\t\t\t\t{proj_debug_id} /* Debug */,")
    L.append(f"\t\t\t\t{proj_release_id} /* Release */,")
    L.append("\t\t\t);")
    L.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    L.append("\t\t\tdefaultConfigurationName = Release;")
    L.append("\t\t};")
    L.append(f"\t\t{target_cfg_list_id} /* Build configuration list for PBXNativeTarget \"Things\" */ = {{")
    L.append("\t\t\tisa = XCConfigurationList;")
    L.append("\t\t\tbuildConfigurations = (")
    L.append(f"\t\t\t\t{target_debug_id} /* Debug */,")
    L.append(f"\t\t\t\t{target_release_id} /* Release */,")
    L.append("\t\t\t);")
    L.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    L.append("\t\t\tdefaultConfigurationName = Release;")
    L.append("\t\t};")
    L.append("/* End XCConfigurationList section */")

    L.append("\t};")
    L.append(f"\trootObject = {proj_id} /* Project object */;")
    L.append("}")
    return "\n".join(L) + "\n"


def main():
    text = build_pbxproj()
    out = PROJ_DIR / "project.pbxproj"
    out.write_text(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
