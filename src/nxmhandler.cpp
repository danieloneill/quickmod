#include "nxmhandler.h"

QString NXMHandler::download(const QString &arg)
{
    emit downloadRequested(arg);
    return tr("Okay, I'll try.");
}
