#!/usr/bin/env python3
"""Generate the native watch project using only Python's standard library."""
from pathlib import Path
import hashlib
import plistlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "PocketPikachuWatch.xcodeproj"
CONFIG = ROOT / "Config"
PROJECT.mkdir(parents=True, exist_ok=True)
CONFIG.mkdir(parents=True, exist_ok=True)


def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'


def plist(name, values):
    (CONFIG / name).write_bytes(plistlib.dumps(values, sort_keys=False))


plist("WatchApp-Info.plist", {
    "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
    "CFBundleDisplayName": "Pocket Pikachu",
    "CFBundleExecutable": "$(EXECUTABLE_NAME)",
    "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
    "CFBundleInfoDictionaryVersion": "6.0",
    "PocketAppGroup": "$(APP_GROUP_IDENTIFIER)",
    "CFBundleName": "$(PRODUCT_NAME)",
    "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
    "WKApplication": True,
    "WKWatchOnly": True,
    "NSHealthShareUsageDescription": "Pocket Pikachu reads your step count to turn walking into watts.",
    "CFBundleURLTypes": [{
        "CFBundleURLName": "$(PRODUCT_BUNDLE_IDENTIFIER)",
        "CFBundleURLSchemes": ["pocketpikachu"],
        "CFBundleTypeRole": "Viewer",
    }],
})
plist("Widgets-Info.plist", {
    "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
    "CFBundleDisplayName": "Pocket Pikachu",
    "CFBundleExecutable": "$(EXECUTABLE_NAME)",
    "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
    "CFBundleInfoDictionaryVersion": "6.0",
    "PocketAppGroup": "$(APP_GROUP_IDENTIFIER)",
    "CFBundleName": "$(PRODUCT_NAME)",
    "CFBundlePackageType": "$(PRODUCT_BUNDLE_PACKAGE_TYPE)",
    "CFBundleShortVersionString": "$(MARKETING_VERSION)",
    "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
    "NSExtension": {"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"},
})
group = {"com.apple.security.application-groups": ["$(APP_GROUP_IDENTIFIER)"]}
plist("WatchApp.entitlements", {**group, "com.apple.developer.healthkit": True})
plist("Widgets.entitlements", group)

(CONFIG / "Base.xcconfig").write_text("""// Set your signing team and registered bundle identifier here.
WATCH_BUNDLE_IDENTIFIER = com.pocketpikachu.watch
APP_GROUP_IDENTIFIER = group.com.pocketpikachu.watch
DEVELOPMENT_TEAM =
CODE_SIGN_STYLE = Automatic
SDKROOT = watchos
SUPPORTED_PLATFORMS = watchos watchsimulator
WATCHOS_DEPLOYMENT_TARGET = 26.0
TARGETED_DEVICE_FAMILY = 4
SWIFT_VERSION = 6.0
CLANG_ENABLE_MODULES = YES
ENABLE_USER_SCRIPT_SANDBOXING = YES
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
GENERATE_INFOPLIST_FILE = NO
""")

objects = []


def obj(name, isa, body):
    objects.append(f"\t\t{uid(name)} /* {name} */ = {{\n\t\t\tisa = {isa};\n{body}\n\t\t}};")
    return uid(name)


def refs(names):
    return "(" + ", ".join(uid(name) for name in names) + ")"


def fields(values):
    return "\n".join(f"\t\t\t{key} = {value};" for key, value in values.items())


for name in ["PocketPikachuWatch", "PocketPikachuWidgets", "Shared"]:
    obj(name, "PBXFileSystemSynchronizedRootGroup", fields({
        "explicitFileTypes": "{}", "explicitFolders": "()", "path": quote(name), "sourceTree": '"<group>"',
    }))
for name, kind in [("PocketPikachuWatch.app", "wrapper.application"), ("PocketPikachuWidgets.appex", "wrapper.app-extension")]:
    obj(name, "PBXFileReference", fields({"explicitFileType": kind, "includeInIndex": "0", "path": quote(name), "sourceTree": "BUILT_PRODUCTS_DIR"}))
obj("Base.xcconfig", "PBXFileReference", fields({"lastKnownFileType": "text.xcconfig", "path": '"Config/Base.xcconfig"', "sourceTree": '"<group>"'}))
for name, kind in [("color-atlas.png", "image.png"), ("animations.json", "text.json")]:
    obj(name, "PBXFileReference", fields({"lastKnownFileType": kind, "path": quote("PocketPikachuWatch/Resources/" + name), "sourceTree": '"<group>"'}))
    obj("Widget " + name, "PBXBuildFile", fields({"fileRef": uid(name)}))
obj("Widget Resources", "PBXGroup", fields({"children": refs(["color-atlas.png", "animations.json"]), "name": '"Widget Resources"', "sourceTree": '"<group>"'}))
obj("Products", "PBXGroup", fields({"children": refs(["PocketPikachuWatch.app", "PocketPikachuWidgets.appex"]), "name": "Products", "sourceTree": '"<group>"'}))
obj("Main Group", "PBXGroup", fields({"children": refs(["PocketPikachuWatch", "PocketPikachuWidgets", "Shared", "Widget Resources", "Base.xcconfig", "Products"]), "sourceTree": '"<group>"'}))
obj("Local WatchCore", "XCLocalSwiftPackageReference", fields({"relativePath": '"."'}))
obj("WatchCore", "XCSwiftPackageProductDependency", fields({"package": uid("Local WatchCore"), "productName": "WatchCore"}))
obj("WatchCore Framework", "PBXBuildFile", fields({"productRef": uid("WatchCore")}))
obj("Embedded Widgets", "PBXBuildFile", fields({"fileRef": uid("PocketPikachuWidgets.appex"), "settings": "{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, );}"}))
obj("Embed App Extensions", "PBXCopyFilesBuildPhase", fields({"buildActionMask": "2147483647", "dstPath": '""', "dstSubfolderSpec": "13", "files": refs(["Embedded Widgets"]), "name": '"Embed App Extensions"', "runOnlyForDeploymentPostprocessing": "0"}))
obj("Widgets Proxy", "PBXContainerItemProxy", fields({"containerPortal": uid("Project"), "proxyType": "1", "remoteGlobalIDString": uid("Widgets"), "remoteInfo": "PocketPikachuWidgets"}))
obj("Widgets Dependency", "PBXTargetDependency", fields({"target": uid("Widgets"), "targetProxy": uid("Widgets Proxy")}))

for target, source, product, info, entitlement in [
    ("App", "PocketPikachuWatch", "PocketPikachuWatch.app", "WatchApp-Info.plist", "WatchApp.entitlements"),
    ("Widgets", "PocketPikachuWidgets", "PocketPikachuWidgets.appex", "Widgets-Info.plist", "Widgets.entitlements"),
]:
    is_app = target == "App"
    for phase, isa in [("Sources", "PBXSourcesBuildPhase"), ("Resources", "PBXResourcesBuildPhase"), ("Frameworks", "PBXFrameworksBuildPhase")]:
        files = refs(["WatchCore Framework"]) if is_app and phase == "Frameworks" else "()"
        if not is_app and phase == "Resources":
            files = refs(["Widget color-atlas.png", "Widget animations.json"])
        obj(f"{target} {phase}", isa, fields({"buildActionMask": "2147483647", "files": files, "runOnlyForDeploymentPostprocessing": "0"}))
    phases = [f"{target} Sources", f"{target} Frameworks", f"{target} Resources"]
    if is_app:
        phases.append("Embed App Extensions")
    obj(target, "PBXNativeTarget", fields({
        "buildConfigurationList": uid(f"{target} Configurations"), "buildPhases": refs(phases), "buildRules": "()",
        "dependencies": refs(["Widgets Dependency"]) if is_app else "()",
        "fileSystemSynchronizedGroups": refs([source, "Shared"]), "name": source,
        "packageProductDependencies": refs(["WatchCore"]) if is_app else "()",
        "productName": source, "productReference": uid(product),
        "productType": quote("com.apple.product-type.application" if is_app else "com.apple.product-type.app-extension"),
    }))
    for mode in ["Debug", "Release"]:
        settings = {
            "PRODUCT_NAME": '"$(TARGET_NAME)"',
            "PRODUCT_BUNDLE_IDENTIFIER": quote("$(WATCH_BUNDLE_IDENTIFIER)" + ("" if is_app else ".widgets")),
            "INFOPLIST_FILE": quote("Config/" + info), "CODE_SIGN_ENTITLEMENTS": quote("Config/" + entitlement),
            "SKIP_INSTALL": "NO" if is_app else "YES", "SWIFT_EMIT_LOC_STRINGS": "YES",
        }
        if not is_app:
            settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
        obj(f"{target} {mode}", "XCBuildConfiguration", fields({"buildSettings": "{ " + " ".join(f"{key} = {value};" for key, value in settings.items()) + " }", "name": mode}))

for mode in ["Debug", "Release"]:
    settings = 'ONLY_ACTIVE_ARCH = YES; SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";' if mode == "Debug" else 'SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
    obj(f"Project {mode}", "XCBuildConfiguration", fields({"baseConfigurationReference": uid("Base.xcconfig"), "buildSettings": "{ " + settings + " }", "name": mode}))
for target in ["Project", "App", "Widgets"]:
    obj(f"{target} Configurations", "XCConfigurationList", fields({"buildConfigurations": refs([f"{target} Debug", f"{target} Release"]), "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"}))
obj("Project", "PBXProject", fields({
    "attributes": "{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2710; TargetAttributes = { " + uid("App") + " = {CreatedOnToolsVersion = 27.1; SystemCapabilities = {com.apple.HealthKit = {enabled = 1;}; com.apple.ApplicationGroups.iOS = {enabled = 1;};};}; " + uid("Widgets") + " = {CreatedOnToolsVersion = 27.1; SystemCapabilities = {com.apple.ApplicationGroups.iOS = {enabled = 1;};};}; }; }",
    "buildConfigurationList": uid("Project Configurations"), "developmentRegion": "en", "hasScannedForEncodings": "0", "knownRegions": "(en, Base)",
    "mainGroup": uid("Main Group"), "minimizedProjectReferenceProxies": "1", "packageReferences": refs(["Local WatchCore"]),
    "preferredProjectObjectVersion": "77", "productRefGroup": uid("Products"), "projectDirPath": '""', "projectRoot": '""', "targets": refs(["App", "Widgets"]),
}))
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 77;\n\tobjects = {\n" + "\n".join(objects) + "\n\t};\n\trootObject = " + uid("Project") + ";\n}\n")
scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("App")}" BuildableName="PocketPikachuWatch.app" BlueprintName="PocketPikachuWatch" ReferencedContainer="container:PocketPikachuWatch.xcodeproj"/>'
(scheme_dir / "PocketPikachuWatch.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print("Generated PocketPikachuWatch.xcodeproj and Config files.")
