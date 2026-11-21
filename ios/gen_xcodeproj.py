#!/usr/bin/env python3
"""Generate ios/OpenListApp/OpenListApp.xcodeproj/project.pbxproj.

The project is written by a generator (not by hand) so the object graph
stays consistent: every referenced ID exists, every file is in exactly
one build phase, and the build settings are the same for Debug/Release
except where noted.

Layout:
    ios/OpenListApp/
      OpenListApp.xcodeproj/project.pbxproj   <- this file
      OpenListApp/*.swift, Info.plist, Assets.xcassets
      OpenListCore.xcframework               <- built by the workflow
                                                 (gomobile bind) before xcodebuild
"""
import hashlib
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
# Conventional layout: ios/OpenListApp/ holds the .xcodeproj, the source
# folder, and (built by the workflow) the xcframework.
OUT = os.path.join(ROOT, "OpenListApp", "OpenListApp.xcodeproj", "project.pbxproj")

SWIFT_FILES = [
    "OpenListAppApp.swift",
    "AppState.swift",
    "ServerBridge.swift",
    "KeychainHelper.swift",
    "APIClient.swift",
    "Models.swift",
    "ContentView.swift",
    "FilesView.swift",
    "FileDetailView.swift",
    "WebDAVView.swift",
    "SettingsView.swift",
    "EmbyView.swift",
    "OpenListActivityAttributes.swift",
    "LiveActivityManager.swift",
    "TabBarLongPress.swift",
    "AppIntents.swift",
]

# Widget Extension（灵动岛 Live Activity 的界面）。
# 扩展的源文件在 ios/OpenListLiveActivity/，
# 共享的 OpenListActivityAttributes.swift 在主 App 目录里，
# 两个 target 都编它（同一个类型，扩展才能认出主 App 的活动）。
EXT_SWIFT_FILES = [
    "OpenListLiveActivity.swift",
]
EXT_INFOPLIST = "Info.plist"


def obj_id(seed: str) -> str:
    return hashlib.sha256(seed.encode()).hexdigest()[:24].upper()


# ---------------------------------------------------------------- IDs
ids = {}
def I(name: str) -> str:
    if name not in ids:
        ids[name] = obj_id("openlist-ios:" + name)
    return ids[name]

PROJECT = I("PBXProject")
TARGET = I("PBXNativeTarget:OpenListApp")
PRODUCT = I("PBXFileReference:OpenListApp.app")
GROUP_MAIN = I("PBXGroup:main")
GROUP_APP = I("PBXGroup:OpenListApp")
GROUP_PRODUCTS = I("PBXGroup:Products")
PHASE_SOURCES = I("PBXSourcesBuildPhase")
PHASE_FRAMEWORKS = I("PBXFrameworksBuildPhase")
PHASE_RESOURCES = I("PBXResourcesBuildPhase")
PHASE_EMBED = I("PBXCopyFilesBuildPhase:Embed Frameworks")
XCFRAMEWORK = I("PBXFileReference:OpenListCore.xcframework")
ASSETS = I("PBXFileReference:Assets.xcassets")
INFOPLIST = I("PBXFileReference:Info.plist")
CONFIG_LIST_PROJECT = I("XCConfigurationList:project")
CONFIG_LIST_TARGET = I("XCConfigurationList:target")
CONFIG_PROJECT_DEBUG = I("XCBuildConfiguration:project:Debug")
CONFIG_PROJECT_RELEASE = I("XCBuildConfiguration:project:Release")
CONFIG_TARGET_DEBUG = I("XCBuildConfiguration:target:Debug")
CONFIG_TARGET_RELEASE = I("XCBuildConfiguration:target:Release")
# Widget Extension（灵动岛 Live Activity）
TARGET_EXT = I("PBXNativeTarget:OpenListLiveActivity")
PRODUCT_EXT = I("PBXFileReference:OpenListLiveActivity.appex")
GROUP_EXT = I("PBXGroup:OpenListLiveActivity")
PHASE_EXT_SOURCES = I("PBXSourcesBuildPhase:OpenListLiveActivity")
PHASE_EXT_FRAMEWORKS = I("PBXFrameworksBuildPhase:OpenListLiveActivity")
PHASE_EMBED_EXT = I("PBXCopyFilesBuildPhase:Embed App Extensions")
DEPENDENCY_EXT = I("PBXTargetDependency:OpenListLiveActivity")
EXT_INFOPLIST_REF = I("PBXFileReference:OpenListLiveActivity:Info.plist")
CONFIG_LIST_TARGET_EXT = I("XCConfigurationList:target:OpenListLiveActivity")
CONFIG_TARGET_EXT_DEBUG = I("XCBuildConfiguration:target:OpenListLiveActivity:Debug")
CONFIG_TARGET_EXT_RELEASE = I("XCBuildConfiguration:target:OpenListLiveActivity:Release")

build_files = {}
for f in SWIFT_FILES:
    build_files[f] = I("PBXBuildFile:" + f)
build_files["xcframework"] = I("PBXBuildFile:OpenListCore.xcframework")
build_files["xcframework_embed"] = I("PBXBuildFile:OpenListCore.xcframework:embed")
build_files["assets"] = I("PBXBuildFile:Assets.xcassets")
# Widget Extension 的源文件（扩展自己的 + 共享的 ActivityAttributes）。
for f in EXT_SWIFT_FILES:
    build_files["ext:" + f] = I("PBXBuildFile:OpenListLiveActivity:" + f)
build_files["ext:shared_attributes"] = I("PBXBuildFile:OpenListLiveActivity:OpenListActivityAttributes.swift")
build_files["ext_embed"] = I("PBXBuildFile:OpenListLiveActivity.appex:embed")

file_refs = {}
for f in SWIFT_FILES:
    file_refs[f] = I("PBXFileReference:" + f)
for f in EXT_SWIFT_FILES:
    file_refs["ext:" + f] = I("PBXFileReference:OpenListLiveActivity:" + f)

# ---------------------------------------------------------------- helpers
def q(s: str) -> str:
    return '"' + s + '"'

lines = []
def emit(s: str = ""):
    lines.append(s)

def section(name: str, body: list):
    emit(f"\n/* Begin {name} section */")
    lines.extend(body)
    emit(f"/* End {name} section */")

# ---------------------------------------------------------------- PBXBuildFile
body = []
for f in SWIFT_FILES:
    body.append(f"\t\t{build_files[f]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {f} */; }};")
body.append(f"\t\t{build_files['xcframework']} /* OpenListCore.xcframework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {XCFRAMEWORK} /* OpenListCore.xcframework */; }};")
body.append(f"\t\t{build_files['xcframework_embed']} /* OpenListCore.xcframework in Embed Frameworks */ = {{isa = PBXBuildFile; fileRef = {XCFRAMEWORK} /* OpenListCore.xcframework */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};")
body.append(f"\t\t{build_files['assets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {ASSETS} /* Assets.xcassets */; }};")
# Widget Extension：自己的源文件 + 共享的 ActivityAttributes（主 App 目录里的同一个文件）。
for f in EXT_SWIFT_FILES:
    body.append(f"\t\t{build_files['ext:' + f]} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs['ext:' + f]} /* {f} */; }};")
body.append(f"\t\t{build_files['ext:shared_attributes']} /* OpenListActivityAttributes.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs['OpenListActivityAttributes.swift']} /* OpenListActivityAttributes.swift */; }};")
body.append(f"\t\t{build_files['ext_embed']} /* OpenListLiveActivity.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {PRODUCT_EXT} /* OpenListLiveActivity.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
section("PBXBuildFile", body)

# ---------------------------------------------------------------- PBXFileReference
body = []
for f in SWIFT_FILES:
    body.append(f"\t\t{file_refs[f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};")
body.append(f"\t\t{XCFRAMEWORK} /* OpenListCore.xcframework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = OpenListCore.xcframework; sourceTree = \"<group>\"; }};")
body.append(f"\t\t{ASSETS} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
body.append(f"\t\t{INFOPLIST} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
body.append(f"\t\t{PRODUCT} /* OpenListApp.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = OpenListApp.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
# Widget Extension 的源文件、Info.plist 和产物（.appex）。
for f in EXT_SWIFT_FILES:
    body.append(f"\t\t{file_refs['ext:' + f]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};")
body.append(f"\t\t{EXT_INFOPLIST_REF} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {EXT_INFOPLIST}; sourceTree = \"<group>\"; }};")
body.append(f"\t\t{PRODUCT_EXT} /* OpenListLiveActivity.appex */ = {{isa = PBXFileReference; explicitFileType = wrapper.app-extension; includeInIndex = 0; path = OpenListLiveActivity.appex; sourceTree = BUILT_PRODUCTS_DIR; }};")
section("PBXFileReference", body)

# ---------------------------------------------------------------- PBXCopyFilesBuildPhase (Embed Frameworks)
# Without this phase the xcframework is only linked, never copied into
# the .app bundle: the .ipa comes out tiny and the app crashes on launch
# (dyld: Library not loaded). dstSubfolderSpec 10 = Frameworks folder.
section("PBXCopyFilesBuildPhase", [
    f"\t\t{PHASE_EMBED} /* Embed Frameworks */ = {{",
    "\t\t\tisa = PBXCopyFilesBuildPhase;",
    "\t\t\tbuildActionMask = 2147483647;",
    "\t\t\tdstPath = \"\";",
    "\t\t\tdstSubfolderSpec = 10;",
    "\t\t\tfiles = (",
    f"\t\t\t\t{build_files['xcframework_embed']} /* OpenListCore.xcframework in Embed Frameworks */,",
    "\t\t\t);",
    "\t\t\tname = \"Embed Frameworks\";",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
    f"\t\t{PHASE_EMBED_EXT} /* Embed App Extensions */ = {{",
    "\t\t\tisa = PBXCopyFilesBuildPhase;",
    "\t\t\tbuildActionMask = 2147483647;",
    "\t\t\tdstPath = \"\";",
    "\t\t\tdstSubfolderSpec = 13;",
    "\t\t\tfiles = (",
    f"\t\t\t\t{build_files['ext_embed']} /* OpenListLiveActivity.appex in Embed App Extensions */,",
    "\t\t\t);",
    "\t\t\tname = \"Embed App Extensions\";",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXFrameworksBuildPhase
section("PBXFrameworksBuildPhase", [
    f"\t\t{PHASE_FRAMEWORKS} /* Frameworks */ = {{",
    "\t\t\tisa = PBXFrameworksBuildPhase;",
    "\t\t\tbuildActionMask = 2147483647;",
    "\t\t\tfiles = (",
    f"\t\t\t\t{build_files['xcframework']} /* OpenListCore.xcframework in Frameworks */,",
    "\t\t\t);",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
    # Widget Extension 只用系统框架（WidgetKit / ActivityKit），
    # Swift import 时自动链接，不用在这里加。
    f"\t\t{PHASE_EXT_FRAMEWORKS} /* Frameworks */ = {{",
    "\t\t\tisa = PBXFrameworksBuildPhase;",
    "\t\t\tbuildActionMask = 2147483647;",
    "\t\t\tfiles = (",
    "\t\t\t);",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXGroup
group_app_children = ",\n".join(
    [f"\t\t\t\t{file_refs[f]} /* {f} */" for f in SWIFT_FILES]
    + [f"\t\t\t\t{ASSETS} /* Assets.xcassets */",
       f"\t\t\t\t{INFOPLIST} /* Info.plist */"]
) + ","
section("PBXGroup", [
    f"\t\t{GROUP_MAIN} = {{",
    "\t\t\tisa = PBXGroup;",
    "\t\t\tchildren = (",
    f"\t\t\t\t{GROUP_APP} /* OpenListApp */,",
    f"\t\t\t\t{GROUP_EXT} /* OpenListLiveActivity */,",
    f"\t\t\t\t{XCFRAMEWORK} /* OpenListCore.xcframework */,",
    f"\t\t\t\t{GROUP_PRODUCTS} /* Products */,",
    "\t\t\t);",
    "\t\t\tsourceTree = \"<group>\";",
    "\t\t};",
    f"\t\t{GROUP_APP} /* OpenListApp */ = {{",
    "\t\t\tisa = PBXGroup;",
    "\t\t\tchildren = (",
    group_app_children,
    "\t\t\t);",
    # NOTE: no `path` here. This group IS the project dir
    # (ios/OpenListApp/): the Swift files, Info.plist and Assets live
    # directly in it, not in an ios/OpenListApp/OpenListApp/ subfolder.
    # (An earlier `path = OpenListApp;` pointed every source at that
    # nonexistent subfolder, so xcodebuild produced a hollow .app and
    # the .ipa came out ~468 B.)
    "\t\t\tname = OpenListApp;",
    "\t\t\tsourceTree = \"<group>\";",
    "\t\t};",
    # Widget Extension 的组：源文件在 ios/OpenListLiveActivity/，
    # 相对项目目录（ios/OpenListApp/）是 ../OpenListLiveActivity。
    f"\t\t{GROUP_EXT} /* OpenListLiveActivity */ = {{",
    "\t\t\tisa = PBXGroup;",
    "\t\t\tchildren = (",
    f"\t\t\t\t{file_refs['ext:OpenListLiveActivity.swift']} /* OpenListLiveActivity.swift */,",
    f"\t\t\t\t{EXT_INFOPLIST_REF} /* Info.plist */,",
    "\t\t\t);",
    "\t\t\tname = OpenListLiveActivity;",
    "\t\t\tpath = ../OpenListLiveActivity;",
    "\t\t\tsourceTree = \"<group>\";",
    "\t\t};",
    f"\t\t{GROUP_PRODUCTS} /* Products */ = {{",
    "\t\t\tisa = PBXGroup;",
    "\t\t\tchildren = (",
    f"\t\t\t\t{PRODUCT} /* OpenListApp.app */,",
    f"\t\t\t\t{PRODUCT_EXT} /* OpenListLiveActivity.appex */,",
    "\t\t\t);",
    "\t\t\tname = Products;",
    "\t\t\tsourceTree = \"<group>\";",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXNativeTarget
sources_files = ",\n".join(
    f"\t\t\t\t{build_files[f]} /* {f} in Sources */" for f in SWIFT_FILES
) + ","
# Widget Extension 的源文件：自己的 + 共享的 ActivityAttributes。
ext_sources_files = ",\n".join(
    [f"\t\t\t\t{build_files['ext:' + f]} /* {f} in Sources */" for f in EXT_SWIFT_FILES]
    + [f"\t\t\t\t{build_files['ext:shared_attributes']} /* OpenListActivityAttributes.swift in Sources */"]
) + ","
section("PBXNativeTarget", [
    f"\t\t{TARGET} /* OpenListApp */ = {{",
    "\t\t\tisa = PBXNativeTarget;",
    "\t\t\tbuildConfigurationList = " + CONFIG_LIST_TARGET + " /* Build configuration list for PBXNativeTarget \"OpenListApp\" */;",
    "\t\t\tbuildPhases = (",
    f"\t\t\t\t{PHASE_SOURCES} /* Sources */,",
    f"\t\t\t\t{PHASE_FRAMEWORKS} /* Frameworks */,",
    f"\t\t\t\t{PHASE_RESOURCES} /* Resources */,",
    f"\t\t\t\t{PHASE_EMBED} /* Embed Frameworks */,",
    f"\t\t\t\t{PHASE_EMBED_EXT} /* Embed App Extensions */,",
    "\t\t\t);",
    "\t\t\tbuildRules = (",
    "\t\t\t);",
    "\t\t\tdependencies = (",
    f"\t\t\t\t{DEPENDENCY_EXT} /* PBXTargetDependency */,",
    "\t\t\t);",
    "\t\t\tname = OpenListApp;",
    f"\t\t\tproductName = OpenListApp;",
    f"\t\t\tproductReference = {PRODUCT} /* OpenListApp.app */;",
    "\t\t\tproductType = \"com.apple.product-type.application\";",
    "\t\t};",
    f"\t\t{TARGET_EXT} /* OpenListLiveActivity */ = {{",
    "\t\t\tisa = PBXNativeTarget;",
    "\t\t\tbuildConfigurationList = " + CONFIG_LIST_TARGET_EXT + " /* Build configuration list for PBXNativeTarget \"OpenListLiveActivity\" */;",
    "\t\t\tbuildPhases = (",
    f"\t\t\t\t{PHASE_EXT_SOURCES} /* Sources */,",
    f"\t\t\t\t{PHASE_EXT_FRAMEWORKS} /* Frameworks */,",
    "\t\t\t);",
    "\t\t\tbuildRules = (",
    "\t\t\t);",
    "\t\t\tdependencies = (",
    "\t\t\t);",
    "\t\t\tname = OpenListLiveActivity;",
    f"\t\t\tproductName = OpenListLiveActivity;",
    f"\t\t\tproductReference = {PRODUCT_EXT} /* OpenListLiveActivity.appex */;",
    "\t\t\tproductType = \"com.apple.product-type.app-extension\";",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXTargetDependency
section("PBXTargetDependency", [
    f"\t\t{DEPENDENCY_EXT} /* PBXTargetDependency */ = {{",
    "\t\t\tisa = PBXTargetDependency;",
    f"\t\t\ttarget = {TARGET_EXT} /* OpenListLiveActivity */;",
    f"\t\t\ttargetProxy = {I('PBXContainerItemProxy:OpenListLiveActivity')} /* PBXContainerItemProxy */;",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXContainerItemProxy
section("PBXContainerItemProxy", [
    f"\t\t{I('PBXContainerItemProxy:OpenListLiveActivity')} /* PBXContainerItemProxy */ = {{",
    "\t\t\tisa = PBXContainerItemProxy;",
    f"\t\t\tcontainerPortal = {PROJECT} /* Project object */;",
    "\t\t\tproxyType = 1;",
    f"\t\t\tremoteGlobalIDString = {TARGET_EXT};",
    f"\t\t\tremoteInfo = OpenListLiveActivity;",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXProject
section("PBXProject", [
    f"\t\t{PROJECT} /* Project object */ = {{",
    "\t\t\tisa = PBXProject;",
    "\t\t\tattributes = {",
    "\t\t\t\tBuildIndependentTargetsInParallel = 1;",
    "\t\t\t\tLastSwiftUpdateCheck = 1600;",
    "\t\t\t\tLastUpgradeCheck = 1600;",
    "\t\t\t\tTargetAttributes = {",
    f"\t\t\t\t\t{TARGET} = {{",
    "\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;",
    "\t\t\t\t\t};",
    f"\t\t\t\t\t{TARGET_EXT} = {{",
    "\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;",
    "\t\t\t\t\t};",
    "\t\t\t\t};",
    "\t\t\t};",
    "\t\t\tbuildConfigurationList = " + CONFIG_LIST_PROJECT + " /* Build configuration list for PBXProject \"OpenListApp\" */;",
    "\t\t\tcompatibilityVersion = \"Xcode 14.0\";",
    "\t\t\tdevelopmentRegion = en;",
    "\t\t\thasScannedForEncodings = 0;",
    "\t\t\tknownRegions = (",
    "\t\t\t\ten,",
    "\t\t\t\tBase,",
    "\t\t\t);",
    f"\t\t\tmainGroup = {GROUP_MAIN};",
    f"\t\t\tproductRefGroup = {GROUP_PRODUCTS} /* Products */;",
    "\t\t\tprojectDirPath = \"\";",
    "\t\t\tprojectRoot = \"\";",
    "\t\t\ttargets = (",
    f"\t\t\t\t{TARGET} /* OpenListApp */,",
    f"\t\t\t\t{TARGET_EXT} /* OpenListLiveActivity */,",
    "\t\t\t);",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXResourcesBuildPhase
section("PBXResourcesBuildPhase", [
    f"\t\t{PHASE_RESOURCES} /* Resources */ = {{",
    "\t\t\tisa = PBXResourcesBuildPhase;",
    "\t\t\tbuildActionMask = 2147483647;",
    "\t\t\tfiles = (",
    f"\t\t\t\t{build_files['assets']} /* Assets.xcassets in Resources */,",
    "\t\t\t);",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
])

# ---------------------------------------------------------------- PBXSourcesBuildPhase
section("PBXSourcesBuildPhase", [
    f"\t\t{PHASE_SOURCES} /* Sources */ = {{",
    "\t\t\tisa = PBXSourcesBuildPhase;",
    "\t\t\tbuildActionMask = 2147483647;",
    "\t\t\tfiles = (",
    sources_files,
    "\t\t\t);",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
    f"\t\t{PHASE_EXT_SOURCES} /* Sources */ = {{",
    "\t\t\tisa = PBXSourcesBuildPhase;",
    "\t\t\tbuildActionMask = 2147483647;",
    "\t\t\tfiles = (",
    ext_sources_files,
    "\t\t\t);",
    "\t\t\trunOnlyForDeploymentPostprocessing = 0;",
    "\t\t};",
])

# ---------------------------------------------------------------- XCBuildConfiguration
def build_settings(indent, settings):
    out = []
    for k, v in settings.items():
        out.append(f"{indent}\t\t\t\t{k} = {v};")
    return out

common_project = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "COPY_PHASE_STRIP": "NO",
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_TESTABILITY": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": '("DEBUG=1", "$(inherited)")',
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
    "LOCALIZATION_PREFS": '""',
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "MTL_FAST_MATH": "YES",
    "ONLY_ACTIVE_ARCH": "YES",
    "SDKROOT": "iphoneos",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"',
}

release_project = dict(common_project)
release_project.update({
    "COPY_PHASE_STRIP": "YES",
    "DEBUG_INFORMATION_FORMAT": '"dwarf-with-dsym"',
    "ENABLE_NS_ASSERTIONS": "NO",
    "ENABLE_TESTABILITY": "NO",
    "GCC_OPTIMIZATION_LEVEL": "s",
    "GCC_PREPROCESSOR_DEFINITIONS": '"$(inherited)"',
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "MTL_FAST_MATH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": '""',
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "SWIFT_OPTIMIZATION_LEVEL": '"-O"',
    "VALIDATE_PRODUCT": "YES",
})
release_project.pop("ONLY_ACTIVE_ARCH", None)

common_target = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "7",
    "FRAMEWORK_SEARCH_PATHS": '("$(inherited)", "$(PROJECT_DIR)")',
    "INFOPLIST_FILE": "Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": '("$(inherited)", "@executable_path/Frameworks")',
    "MARKETING_VERSION": "4.2.9.7",
    # Go runtime (OpenListCore) calls res_9_ninit/res_9_nsearch/res_9_nclose
    # for DNS; on iOS those live in libresolv. Without -lresolv the link
    # fails with "Undefined symbols ... _res_9_nclose" etc.
    "OTHER_LDFLAGS": '"$(inherited) -lresolv"',
    "PRODUCT_BUNDLE_IDENTIFIER": "com.openlist.ios",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMBED_LIBRARIES_WITH_INSTALL": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1",
}
release_target = dict(common_target)

# Widget Extension（灵动岛 Live Activity）的编译设置。
# 部署目标 16.1：Live Activity / ActivityConfiguration 要 iOS 16.1+。
# APPLICATION_EXTENSION_API_ONLY 必须开：扩展只能用扩展安全的 API。
common_target_ext = {
    "APPLICATION_EXTENSION_API_ONLY": "YES",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "7",
    "INFOPLIST_FILE": "../OpenListLiveActivity/Info.plist",
    "IPHONEOS_DEPLOYMENT_TARGET": "16.1",
    "LD_RUNPATH_SEARCH_PATHS": '("$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks")',
    "MARKETING_VERSION": "4.2.9.7",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.openlist.ios.OpenListLiveActivity",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_EMBED_LIBRARIES_WITH_INSTALL": "YES",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1",
}
release_target_ext = dict(common_target_ext)

def config_block(cfg_id, name, settings, comment):
    out = [f"\t\t{cfg_id} /* {comment} */ = {{"]
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.extend(build_settings("\t", settings))
    out.append("\t\t\t};")
    out.append(f"\t\t\tname = {name};")
    out.append("\t\t};")
    return out

section("XCBuildConfiguration", [
    *config_block(CONFIG_PROJECT_DEBUG, "Debug", common_project, "Debug"),
    *config_block(CONFIG_PROJECT_RELEASE, "Release", release_project, "Release"),
    *config_block(CONFIG_TARGET_DEBUG, "Debug", common_target, "Debug"),
    *config_block(CONFIG_TARGET_RELEASE, "Release", release_target, "Release"),
    *config_block(CONFIG_TARGET_EXT_DEBUG, "Debug", common_target_ext, "Debug"),
    *config_block(CONFIG_TARGET_EXT_RELEASE, "Release", release_target_ext, "Release"),
])

# ---------------------------------------------------------------- XCConfigurationList
section("XCConfigurationList", [
    f"\t\t{CONFIG_LIST_PROJECT} /* Build configuration list for PBXProject \"OpenListApp\" */ = {{",
    "\t\t\tisa = XCConfigurationList;",
    "\t\t\tbuildConfigurations = (",
    f"\t\t\t\t{CONFIG_PROJECT_DEBUG} /* Debug */,",
    f"\t\t\t\t{CONFIG_PROJECT_RELEASE} /* Release */,",
    "\t\t\t);",
    "\t\t\tdefaultConfigurationIsVisible = 0;",
    "\t\t\tdefaultConfigurationName = Release;",
    "\t\t};",
    f"\t\t{CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget \"OpenListApp\" */ = {{",
    "\t\t\tisa = XCConfigurationList;",
    "\t\t\tbuildConfigurations = (",
    f"\t\t\t\t{CONFIG_TARGET_DEBUG} /* Debug */,",
    f"\t\t\t\t{CONFIG_TARGET_RELEASE} /* Release */,",
    "\t\t\t);",
    "\t\t\tdefaultConfigurationIsVisible = 0;",
    "\t\t\tdefaultConfigurationName = Release;",
    "\t\t};",
    f"\t\t{CONFIG_LIST_TARGET_EXT} /* Build configuration list for PBXNativeTarget \"OpenListLiveActivity\" */ = {{",
    "\t\t\tisa = XCConfigurationList;",
    "\t\t\tbuildConfigurations = (",
    f"\t\t\t\t{CONFIG_TARGET_EXT_DEBUG} /* Debug */,",
    f"\t\t\t\t{CONFIG_TARGET_EXT_RELEASE} /* Release */,",
    "\t\t\t);",
    "\t\t\tdefaultConfigurationIsVisible = 0;",
    "\t\t\tdefaultConfigurationName = Release;",
    "\t\t};",
])

# ---------------------------------------------------------------- assemble
header = """// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {
"""
footer = f"""\t}};
\trootObject = {PROJECT} /* Project object */;
}}
"""

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    f.write(header)
    f.write("\n".join(lines))
    f.write("\n")
    f.write(footer)

print("wrote", OUT)
print("objects:", len(ids) + len(build_files) + len(file_refs))
