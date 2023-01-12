#ifndef SQLDATABASE_H
#define SQLDATABASE_H

#include <QQuickItem>
#include <QSqlDatabase>
#include <QSqlDriver>
#include <QSqlError>
#include <QSqlField>
#include <QSqlQuery>
#include <QMutex>
#include <QVariantList>
#include <QVariantMap>

#include "sqldatabasemodel.h"

class SqlDatabase;
class SqlDatabaseModel;
class SqlDatabaseConnection;
class SqlDatabaseQuery;

/**
  * A container to hold a QSqlQuery instance handle for (ab)use in a script.
  */
class SqlDatabaseQuery : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    SqlDatabaseConnection *m_parent;
    QSqlQuery   m_query;

    SqlDatabaseQuery(SqlDatabaseConnection *parent=0);

    Q_INVOKABLE void destroy();
    Q_INVOKABLE qulonglong rowCount();
    Q_INVOKABLE int selectRow(qulonglong row);
    Q_INVOKABLE int fieldCount();
    Q_INVOKABLE QString fieldName(int index);
    Q_INVOKABLE QVariant value(QVariant index);
    Q_INVOKABLE QVariant row(qulonglong row);
    Q_INVOKABLE QVariantList toArray();
    Q_INVOKABLE QVariant lastInsertId();
};

/**
  * A container to hold a QSqlDatabase instance handle for (ab)use in a script.
  */
class SqlDatabaseConnection : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    SqlDatabase     *m_parent;
    QSqlDatabase    m_db;
    QMutex          m_mutex;

    SqlDatabaseConnection(SqlDatabase *parent=0);

    Q_INVOKABLE bool ping(); // fixme; a bit hacky:
    Q_INVOKABLE void close();
    Q_INVOKABLE SqlDatabaseQuery *query(const QString &string, QVariantList params=QVariantList());
    Q_INVOKABLE QString escape(const QString &string);
    Q_INVOKABLE QByteArray fromMap(const QVariantMap &map, bool base64=true);
    Q_INVOKABLE QVariantMap toMap(const QByteArray &str, bool base64=true);
    Q_INVOKABLE QString lastError();

    // Transactions:
    Q_INVOKABLE bool transaction();
    Q_INVOKABLE bool commit();
    Q_INVOKABLE bool rollback();

    Q_INVOKABLE SqlDatabaseModel *model();
};

/**
* This class provides database functionality to QML.
*
* @author Daniel F O'Neill <doneill@piratepos.com>
* @version 1.0
*/
class SqlDatabase : public QQuickItem
{
    Q_OBJECT
    Q_DISABLE_COPY(SqlDatabase)
    QML_ELEMENT

    QObject         *m_parent;

public:
    SqlDatabase(QQuickItem *parent = 0);
    ~SqlDatabase();

    Q_INVOKABLE SqlDatabaseConnection *open( const QString &type, const QString &dbname, const QVariantMap &params=QVariantMap() );
    Q_INVOKABLE QStringList availableDrivers();
};


#endif // SQLDATABASE_H

