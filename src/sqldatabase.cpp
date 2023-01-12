#include "sqldatabase.h"
#include "sqldatabasemodel.h"

#define __DB_MAGIC "FusRohDah"
#define __DB_Q_MAGIC "HerpDerp"

SqlDatabase::SqlDatabase(QQuickItem *parent):
    QQuickItem(parent)
{
    m_parent = parent;
}

SqlDatabase::~SqlDatabase()
{
}

SqlDatabaseConnection *SqlDatabase::open(const QString &type, const QString &dbname, const QVariantMap &params)
{
    // FIXME: This may not be portable:
    QString connName = QString("sql_%1_%2").arg( QString::number( (qulonglong)this, 16 )).arg( rand() );

    SqlDatabaseConnection *c = new SqlDatabaseConnection(this);
    c->m_db = QSqlDatabase::addDatabase(type, connName);

    if( !c->m_db.isValid() )
    {
        qWarning() << "SqlDatabase::scriptOpen failed to create a database of type" << type;
        qWarning() << "Supported types are" << QSqlDatabase::drivers();
        delete c;
        return NULL;
    }

    c->m_db.setDatabaseName(dbname);

    if( !params.isEmpty() )
    {
        QStringList options;
        foreach( QString key, params.keys() )
        {
            QString value = params[key].toString();

            if( key == "hostname" )
                c->m_db.setHostName(value);
            else if( key == "port" )
                c->m_db.setPort(value.toInt());
            else if( key == "username" )
                c->m_db.setUserName(value);
            else if( key == "password" )
                c->m_db.setPassword(value);
            else
                options.append(key + "=" + value);
        }

        if( !options.isEmpty() )
            c->m_db.setConnectOptions(options.join(";"));
    }

    bool online = c->m_db.open();
    if( !online )
    {
        qWarning() << "Failed to connect to database:" << c->m_db.lastError();
        delete c;
        return NULL;
    }

    return c;
}

QStringList SqlDatabase::availableDrivers()
{
    return QSqlDatabase::drivers();
}

SqlDatabaseConnection::SqlDatabaseConnection(SqlDatabase *parent)
    : QObject(parent)
{
    m_parent = parent;
}

bool SqlDatabaseConnection::ping()
{
    m_mutex.lock();
    if( !m_db.isOpen() )
        m_db.open();

    QSqlQuery q( m_db );
    if( !q.exec("SELECT 1") )
        m_db.open();

    bool ret = m_db.isOpen();
    m_mutex.unlock();

    return ret;
}

void SqlDatabaseConnection::close()
{
    m_db.close();
    //this->deleteLater();
}

SqlDatabaseQuery *SqlDatabaseConnection::query(const QString &string, QVariantList params)
{
    if( !ping() )
    {
        qWarning() << "This query cannot instantiate because the database connection lost and cannot be re-established.";
        return NULL;
    }

    QSqlQuery q(m_db);
    q.prepare(string);

    int x=0;
    foreach( QVariant arg, params )
        q.bindValue(x++, arg);

    m_mutex.lock();
    bool iret = q.exec();
    m_mutex.unlock();

    if( !iret )
    {
        qWarning() << "SqlDatabase::query execution error:" << q.lastError();
        return NULL;
    }

    SqlDatabaseQuery *dbq = new SqlDatabaseQuery(this);
    dbq->m_query = std::move(q);
    return dbq;
}

QString SqlDatabaseConnection::escape(const QString &string)
{
    // Round-about way of escaping values.
    QSqlField sf = QSqlField("generic", QVariant::String);
    sf.setValue(string);
    QString result = m_db.driver()->formatValue(sf);

    return result;
}

QByteArray SqlDatabaseConnection::fromMap(const QVariantMap &map, bool base64)
{
    QByteArray vba;
    QDataStream qds(&vba, QIODevice::ReadWrite);

    QVariant vvar = QVariant(map);
    qds << vvar;

    if( !base64 )
        return vba;

    QByteArray b64 = vba.toBase64();
    return b64;
}

QVariantMap SqlDatabaseConnection::toMap(const QByteArray &str, bool base64)
{
    QByteArray b64;
    QDataStream *qds;
    if( base64 )
    {
        qds = new QDataStream(b64);
        b64 = QByteArray::fromBase64( str );
    }
    else
        qds = new QDataStream(str);

    QVariant vvar;
    *qds >> vvar;
    delete qds;

    return vvar.toMap();
}

QString SqlDatabaseConnection::lastError()
{
    m_mutex.lock();
    QString ret = m_db.lastError().text();
    m_mutex.unlock();
    return ret;
}

bool SqlDatabaseConnection::transaction()
{
    m_mutex.lock();
    bool ret = m_db.transaction();
    m_mutex.unlock();
    return ret;
}

bool SqlDatabaseConnection::commit()
{
    m_mutex.lock();
    bool ret = m_db.commit();
    m_mutex.unlock();
    return ret;
}

bool SqlDatabaseConnection::rollback()
{
    m_mutex.lock();
    bool ret = m_db.rollback();
    m_mutex.unlock();
    return ret;
}

SqlDatabaseModel *SqlDatabaseConnection::model()
{
    SqlDatabaseModel *m = new SqlDatabaseModel(this);
    m->setDatabase(this);
    return m;
}

SqlDatabaseQuery::SqlDatabaseQuery(SqlDatabaseConnection *parent)
    : QObject(parent)
{
    m_parent = parent;
}

void SqlDatabaseQuery::destroy()
{
    deleteLater();
}

qulonglong SqlDatabaseQuery::rowCount()
{
    m_parent->m_mutex.lock();
    qulonglong size = m_query.size();
    m_parent->m_mutex.unlock();
    return size;
}

int SqlDatabaseQuery::selectRow(qulonglong row)
{
    m_parent->m_mutex.lock();
    int ret = m_query.seek(row);
    m_parent->m_mutex.unlock();
    return ret;
}

int SqlDatabaseQuery::fieldCount()
{
    m_parent->m_mutex.lock();
    int count = m_query.record().count();
    m_parent->m_mutex.unlock();
    return count;
}

QString SqlDatabaseQuery::fieldName(int index)
{
    m_parent->m_mutex.lock();
    QString ret = m_query.record().fieldName(index);
    m_parent->m_mutex.unlock();
    return ret;
}

QVariant SqlDatabaseQuery::value(QVariant field)
{
    m_parent->m_mutex.lock();
    if( field.canConvert<int>() )
    {
        // Numeric field index.
        int idx = field.toInt();
        QVariant ret = m_query.value(idx);
        m_parent->m_mutex.unlock();
        return ret;
    }

    QString name = field.toString();
    QSqlField f = m_query.record().field(name);
    QVariant result = f.value();
    m_parent->m_mutex.unlock();
    return result;
}

QVariant SqlDatabaseQuery::row(qulonglong row)
{
    m_parent->m_mutex.lock();
    bool ret = m_query.seek(row);
    if( !ret )
    {
        m_parent->m_mutex.unlock();
        return false;
    }

    int fc = m_query.record().count();

    QStringList fnames;
    for( int x=0; x < fc; x++ )
        fnames << m_query.record().fieldName(x);

    QVariantMap result;
    for( int x=0; x < fc; x++ )
        result[ fnames[x] ] = m_query.value(x);
    m_parent->m_mutex.unlock();

    return result;
}

QVariantList SqlDatabaseQuery::toArray()
{
    m_parent->m_mutex.lock();
    int fc = m_query.record().count();

    QStringList fnames;
    for( int x=0; x < fc; x++ )
        fnames << m_query.record().fieldName(x);

    QVariantList results;
    while( m_query.next() )
    {
        QVariantMap row;
        for( int x=0; x < fc; x++ )
            row[ fnames[x] ] = m_query.value(x);

        results << row;
    }
    m_parent->m_mutex.unlock();

    return results;
}

QVariant SqlDatabaseQuery::lastInsertId()
{
    m_parent->m_mutex.lock();
    QVariant ret = m_query.lastInsertId();
    m_parent->m_mutex.unlock();
    return ret;
}

