#include <QThread>
#include <QApplication>
#include <stdio.h>
#include <cmath>
#include <time.h>
#include <string>
#include "mainwindow.h"
#include "QDebug"

bool g_debugging = false;

int main(int argc, char** argv)
{
    QCoreApplication::setOrganizationName("Frank Buss");
    QCoreApplication::setOrganizationDomain("frank-buss.de");
    QCoreApplication::setApplicationName("Kerberos App");

    QApplication a(argc, argv);
    MainWindow w;
    for(int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "debugging") {
            g_debugging = true;
        } else if (arg == "--help" || arg == "-h" || arg == "/?") {
            printf("kerberos [--prg <program filename> [--transfer]] [debugging]\n");
            return EXIT_SUCCESS;
        } else if (arg == "--prg" || arg == "/prg") {
            if (i == argc-1) {
                fprintf(stderr, "missing argument for %s\n", arg.c_str());
                return EXIT_FAILURE;
            }
            const char *filename = argv[++i];
            if (! w.loadFile(filename)) {
                fprintf(stderr, "could not load %s\n", filename);
                return EXIT_FAILURE;
            }
            if (i < argc-1) {
                arg = argv[i+1];
                if (arg == "--transfer" || arg == "/transfer") {
                    ++i;
                    if (w.onUploadAndRunPrg()) {
                        return EXIT_SUCCESS;
                    }
                    fprintf(stderr, "could not upload and run %s\n", filename);
                    return EXIT_FAILURE;
                }
            }
        }
    }
	w.show();

	return a.exec();
}

//
// Editor modelines  -  https://www.wireshark.org/tools/modelines.html
//
// Local variables:
// c-basic-offset: 4
// tab-width: 4
// indent-tabs-mode: nil
// End:
//
// vi: set shiftwidth=4 tabstop=4 expandtab:
// :indentSize=4:tabSize=4:noTabs=true:
//
