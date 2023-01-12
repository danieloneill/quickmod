#include "sqldatabase.h"
#include "sqldatabasemodel.h"
#include <QDebug>

SqlDatabaseModel::SqlDatabaseModel(QObject *parent)
    : QSqlQueryModel(parent)
{
}


QVariant SqlDatabaseModel::data(const QModelIndex &index, int role) const
{
    QVariant value = QSqlQueryModel::data(index, role);
    if( role < Qt::UserRole )
        value = QSqlQueryModel::data(index, role);
    else
    {
        int columnIdx = role - Qt::UserRole - 1;
        QModelIndex modelIndex = this->index(index.row(), columnIdx);
        value = QSqlQueryModel::data(modelIndex, Qt::DisplayRole);
    }
    return value;
}

bool SqlDatabaseModel::setSqlQuery(const QString &query, const QVariantList &args)
{
    m_query = QSqlQuery(m_db->m_db);
    int tries = 0;

try_sql_query:
    if( !m_query.prepare(query) )
    {
        if( tries < 1 && m_query.lastError().type() == QSqlError::ConnectionError )
        {
            tries++;

            m_db->m_db.close();
            if( !m_db->m_db.open() )
            {
                qWarning() << "SqlDatabaseModel::setSqlQuery(): Connection to database lost, cannot re-establish:" << m_db->m_db.lastError();
                return false;
            }

            goto try_sql_query;
        }
        else
        {
            qWarning() << "SqlDatabaseModel::setSqlQuery(): Prepare failed:" << m_query.lastError();
            return false;
        }
    }

    for( int x=0; x < args.count(); x++ )
        m_query.bindValue(x, args[x]);

    if( !m_query.exec() )
    {
        qWarning() << "SqlDatabaseModel::setSqlQuery: Failed to execute query:" << m_query.lastError();
        return false;
    }

    generateRoleNames();

    QSqlQueryModel::setQuery(m_query);
    if( lastError().isValid() )
    {
        qWarning() << "SqlDatabaseModel::setSqlQuery: setQuery Error:" << lastError();
        return false;
    }

    return true;
}

int SqlDatabaseModel::rowCount( const QModelIndex &parent )
{
    return QSqlQueryModel::rowCount(parent);
}

QVariant SqlDatabaseModel::get( int rowIdx, const QString &field )
{
    int fieldIdx = record().indexOf(field);
    if( -1 == fieldIdx )
    {
        qWarning() << "SqlDatabaseModel::get(): Field '" << field << "' does not exist in the current query.";
        return QVariant();
    }

    return get( rowIdx, fieldIdx );
}

QVariant SqlDatabaseModel::get( int rowIdx, int columnIdx )
{
    QModelIndex modelIndex = this->index(rowIdx, columnIdx);
    return QSqlQueryModel::data(modelIndex, Qt::DisplayRole);
}

void SqlDatabaseModel::select()
{
    m_query.exec();
    QSqlQueryModel::setQuery(m_query);
    emit layoutChanged();
}

void SqlDatabaseModel::setDatabase(SqlDatabaseConnection *db)
{
    m_db = db;
}

void SqlDatabaseModel::generateRoleNames()
{
    QHash<int, QByteArray> roleNames;
    for( int i = 0; i < m_query.record().count(); i++ )
        roleNames[Qt::UserRole + i + 1] = m_query.record().fieldName(i).toLocal8Bit();

#if QT_VERSION >= QT_VERSION_CHECK(5,0,0)
    m_roleNames = roleNames;
#else
    setRoleNames(roleNames);
#endif
}

#if QT_VERSION >= QT_VERSION_CHECK(5,0,0)
QHash<int, QByteArray> SqlDatabaseModel::roleNames() const
{
    return m_roleNames;
}
#endif
