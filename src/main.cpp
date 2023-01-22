#include <QApplication>
#include <QDebug>
#include <QFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>

#include "file.h"
#include "fomodreader.h"
#include "http.h"
#include "modreader.h"
#include "nxmhandler.h"
#include "sqldatabase.h"
#include "sqldatabasemodel.h"
#include "utils.h"

#define SERVICE_NAME "org.oneill.Quickmod"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QApplication app(argc, argv);
    app.setOrganizationDomain("org.oneill");
    app.setOrganizationName("Quickmod");
    app.setApplicationName("quickmod");
    app.setApplicationVersion("1.0");

    QStringList args;

    for( int i=1; i < argc; i++ )
    {
        qDebug() << "arg:" << argv[i];

        QString arg = QString(argv[i]);
        args << arg;

        if( arg.startsWith('-') )
            continue;
        else
        {
            QString path = QString(argv[i]);
            if( !path.startsWith("nxm") )
            {
                qDebug() << "Ehhh, I expect an nxm:// URL";
                return 3;
            }

            if( !QDBusConnection::sessionBus().isConnected() )
            {
                qDebug() << "Cannot connect to the D-Bus session bus.\n"
                         << "To start it, run:\n"
                         << "\teval `dbus-launch --auto-syntax`\n";
                return 1;
            }

            QDBusInterface iface(SERVICE_NAME, "/", "", QDBusConnection::sessionBus());
            if( iface.isValid() )
            {
                QDBusReply<QString> reply = iface.call("download", path);
                if (reply.isValid()) {
                    qDebug() << "Reply was:" << qPrintable(reply.value());
                    return 0;
                }

                qDebug() << "Call failed:" << qPrintable(reply.error().message());
                return 1;
            }

            qDebug() << qPrintable(QDBusConnection::sessionBus().lastError().message());
            return 2;
        }
    }

    QQmlApplicationEngine engine;


    File *file = new File(&engine);
    ModReader *modReader = new ModReader(file);
    FOMODReader *fomod = new FOMODReader();
    Utils *utils = new Utils();
    NXMHandler *nxmHandler = new NXMHandler();
    HTTP *http = new HTTP(&engine);

    engine.rootContext()->setContextProperty("File", file);
    engine.rootContext()->setContextProperty("FomodReader", fomod);
    engine.rootContext()->setContextProperty("ModReader", modReader);
    engine.rootContext()->setContextProperty("Utils", utils);
    engine.rootContext()->setContextProperty("NXMHandler", nxmHandler);
    engine.rootContext()->setContextProperty("HTTP", http);
    engine.rootContext()->setContextProperty("Args", args);

    qmlRegisterUncreatableType<ArchiveExtractToFileWorker>("org.ONeill.ArchiveExtractToFileWorker", 1, 0, "ArchiveExtractToFileWorker", "Instantiated with Archive.extract(matrix, funcFinished)");
    qmlRegisterUncreatableType<ArchiveExtractToMemoryWorker>("org.ONeill.ArchiveExtractToMemory", 1, 0, "ArchiveExtractToMemory", "Instantiated with Archive.get(target, funcFinished)");
    qmlRegisterUncreatableType<ArchiveListWorker>("org.ONeill.ArchiveList", 1, 0, "ArchiveList", "Instantiated with Archive.list(funcFinished)");
    qmlRegisterUncreatableType<ArchiveController>("org.ONeill.Archive", 1, 0, "Archive", "Instantiated with File.archive('path')");

    qmlRegisterUncreatableType<HTTPHandle>("org.ONeill.HTTPHandle", 1, 0, "HTTPHandle", "Instantiated with HTTP.get or HTTP.getFile");

    qmlRegisterType<SqlDatabase>("org.ONeill.Sql", 1, 0, "SqlDatabase");
    qmlRegisterUncreatableType<SqlDatabaseQuery>("org.ONeill.Sql", 1, 0, "SqlDatabaseQuery", "SQL database query instantiated by SqlDatabaseConnection::query");
    qmlRegisterUncreatableType<SqlDatabaseConnection>("org.ONeill.Sql", 1, 0, "SqlDatabaseConnection", "SQL database connection object instantiated by SqlDatabase::open");
    qmlRegisterUncreatableType<SqlDatabaseModel>("org.ONeill.Sql", 1, 0, "SqlDatabaseModel", "SQL database model object instantiated from SqlDatabase::model");

    if (!QDBusConnection::sessionBus().registerService(SERVICE_NAME)) {
        fprintf(stderr, "%s\n",
                qPrintable(QDBusConnection::sessionBus().lastError().message()));
        exit(1);
    }
    QDBusConnection::sessionBus().registerObject("/", nxmHandler, QDBusConnection::ExportAllSlots);

    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(url);

    int ret = app.exec();

    delete file;
    delete fomod;
    delete utils;
    delete nxmHandler;
    delete http;

    return ret;
}
