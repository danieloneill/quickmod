QT += quick widgets sql dbus

# You can make your code fail to compile if it uses deprecated APIs.
# In order to do so, uncomment the following line.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += \
        src/file.cpp \
        src/http.cpp \
        src/main.cpp \
        src/fomodreader.cpp \
        src/modreader.cpp \
        src/nxmhandler.cpp \
        src/utils.cpp \
        src/sqldatabase.cpp \
        src/sqldatabasemodel.cpp

HEADERS += \
    src/file.h \
    src/fomodreader.h \
    src/http.h \
    src/modreader.h \
    src/nxmhandler.h \
    src/utils.h \
    src/sqldatabase.h \
    src/sqldatabasemodel.h

RESOURCES += qml.qrc

LIBS += -larchive

# Additional import path used to resolve QML modules in Qt Creator's code model
QML_IMPORT_PATH =

# Additional import path used to resolve QML modules just for Qt Quick Designer
QML_DESIGNER_IMPORT_PATH =

# Default rules for deployment.
qnx: target.path = /tmp/$${TARGET}/bin
else: unix:!android: target.path = /opt/$${TARGET}/bin
!isEmpty(target.path): INSTALLS += target
