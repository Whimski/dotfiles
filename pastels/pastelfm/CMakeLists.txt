cmake_minimum_required(VERSION 3.21)

project(PastelFM VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Concurrent)

qt_standard_project_setup(REQUIRES 6.5)

# Generate qmldir entries for the qml/components subdirectory.
if(POLICY CMP0000)
endif()
qt_policy(SET QTP0004 NEW)

qt_add_executable(pastelfm
    src/main.cpp
    src/FileSystemModel.h   src/FileSystemModel.cpp
    src/FileOperations.h    src/FileOperations.cpp
    src/MountManager.h      src/MountManager.cpp
    src/SettingsStore.h     src/SettingsStore.cpp
)

qt_add_qml_module(pastelfm
    URI PastelFM
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Toolbar.qml
        qml/Sidebar.qml
        qml/FileView.qml
        qml/components/FileDelegate.qml
        qml/components/PastelButton.qml
        qml/components/SettingsDialog.qml
        qml/components/ConnectDialog.qml
        qml/components/RenameDialog.qml
        qml/components/NewFolderDialog.qml
        qml/components/ConfirmDialog.qml
        qml/components/PropertiesDialog.qml
)

target_link_libraries(pastelfm PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Concurrent
)

# Resolve the shared "pasteltheme" QML module (lives outside this project, at
# ~/dotfiles/pastels/pasteltheme) so qmllint/qmlcachegen can find it at build time.
# Overridable at runtime via the engine import path in main.cpp.
set(PASTEL_THEME_IMPORT_PATH "$ENV{HOME}/dotfiles/pastels" CACHE PATH "Dir containing the pasteltheme QML module")
set_target_properties(pastelfm PROPERTIES QT_QML_IMPORT_PATH "${PASTEL_THEME_IMPORT_PATH}")

install(TARGETS pastelfm
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION bin
)
