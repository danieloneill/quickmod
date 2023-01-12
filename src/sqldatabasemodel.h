#ifndef PIRATESQLMODEL_H
#define PIRATESQLMODEL_H

#include <QList>
#include <QSqlQuery>
#include <QSqlQueryModel>
#include <QSqlRecord>
#include <QString>

class SqlDatabaseConnection;
class SqlDatabaseModel : public QSqlQueryModel
{
    Q_OBJECT

public:
    explicit SqlDatabaseModel(QObject *parent = 0);

    QVariant data(const QModelIndex &index, int role) const;
    Q_INVOKABLE bool setSqlQuery(const QString &query, const QVariantList &args=QVariantList());
    Q_INVOKABLE int rowCount( const QModelIndex &parent=QModelIndex() );
    Q_INVOKABLE QVariant get(int rowIdx, const QString &field );
    Q_INVOKABLE QVariant get( int rowIdx, int columnIdx );
    Q_INVOKABLE void select();
    void setDatabase(SqlDatabaseConnection *db);
    void generateRoleNames();
#if QT_VERSION >= QT_VERSION_CHECK(5,0,0)
    QHash<int, QByteArray> roleNames() const;
#endif

private:
    SqlDatabaseConnection     *m_db;
    QSqlQuery   m_query;

#if QT_VERSION >= QT_VERSION_CHECK(5,0,0)
    QHash<int, QByteArray> m_roleNames;
#endif
};

#endif // PIRATESQLMODEL_H
