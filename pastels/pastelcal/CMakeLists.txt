cmake_minimum_required(VERSION 3.21)

project(PastelCal VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network NetworkAuth)

qt_standard_project_setup(REQUIRES 6.5)
qt_policy(SET QTP0004 NEW)

qt_add_executable(pastelcal
    src/main.cpp
    src/SettingsStore.h        src/SettingsStore.cpp
    src/CalendarController.h   src/CalendarController.cpp
    src/GoogleCalendarService.h src/GoogleCalendarService.cpp
    src/IcsService.h           src/IcsService.cpp
)

qt_add_qml_module(pastelcal
    URI PastelCal
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/TopBar.qml
        qml/SideBar.qml
        qml/MonthView.qml
        qml/AgendaView.qml
        qml/components/EventChip.qml
        qml/components/EventDialog.qml
        qml/components/SettingsDialog.qml
)

target_link_libraries(pastelcal PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
    Qt6::NetworkAuth
)

# Resolve the shared "pasteltheme" QML module (lives at ~/dotfiles/pastels/pasteltheme).
set(PASTEL_THEME_IMPORT_PATH "$ENV{HOME}/dotfiles/pastels" CACHE PATH "Dir containing the pasteltheme QML module")
set_target_properties(pastelcal PROPERTIES QT_QML_IMPORT_PATH "${PASTEL_THEME_IMPORT_PATH}")

install(TARGETS pastelcal
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION bin
)
