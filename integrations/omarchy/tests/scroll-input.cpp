// Send actual Qt pixel/angle wheel events; QML TestCase.mouseWheel is angle-only.
#include <QGuiApplication>
#include <QElapsedTimer>
#include <QQuickItem>
#include <QQuickView>
#include <QTest>
#include <QWheelEvent>
#include <cmath>
#include <stdexcept>
#include <iostream>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QElapsedTimer clock; clock.start();
    QQuickView view;
    view.setSource(QUrl::fromLocalFile(argv[1]));
    view.show();
    for (int i = 0; i < 30 && view.status() == QQuickView::Loading; ++i) QTest::qWait(100);
    if (view.status() != QQuickView::Ready) {
        std::cerr << "QML load status: " << view.status() << std::endl;
        for (const auto &error : view.errors()) std::cerr << error.toString().toStdString() << std::endl;
        return 1;
    }
    QTest::qWait(300);
    auto *scroll = view.rootObject()->findChild<QQuickItem *>("smooth-scroll-view");
    if (!scroll) { std::cerr << "Scroll view not found" << std::endl; return 1; }
    auto *viewport = scroll->property("contentItem").value<QQuickItem *>();
    if (!viewport) { std::cerr << "Viewport not found" << std::endl; return 1; }
    auto y = [&] { return viewport->property("contentY").toDouble(); };
    auto check = [](bool ok, const char *message) { if (!ok) throw std::runtime_error(message); };
    // Qt platform wheel events carry angle deltas alongside high-resolution pixels.
    auto wheel = [&](int pixels, int angle, Qt::ScrollPhase phase) {
        QPointF local(100, 100);
        QWheelEvent event(local, view.mapToGlobal(local), QPoint(0, pixels), QPoint(0, angle ? angle : pixels),
                          Qt::NoButton, Qt::NoModifier, phase, false);
        event.setTimestamp(clock.elapsed());
        QCoreApplication::sendEvent(&view, &event);
        QTest::qWait(16);
    };
    auto gesture = [&](int delta, bool phased) {
        if (phased) wheel(0, 0, Qt::ScrollBegin);
        for (int i = 0; i < 8; ++i) wheel(delta, 0, phased ? Qt::ScrollUpdate : Qt::NoScrollPhase);
        if (phased) wheel(0, 0, Qt::ScrollEnd);
    };
    auto stop = [&] { QMetaObject::invokeMethod(scroll, "stopMotion"); QTest::qWait(20); };
    try {
        gesture(-18, true);
        double released = y();
        QTest::qWait(130);
        check(y() > released + 20, "phased trackpad stops immediately on release");
        QTest::mouseClick(&view, Qt::LeftButton, Qt::NoModifier, QPoint(100, 100));
        double clicked = y();
        QTest::qWait(200);
        check(std::abs(y() - clicked) < 2, "click did not stop momentum");

        viewport->setProperty("contentY", 1000);
        gesture(-18, false);
        released = y();
        QTest::qWait(220);
        check(y() > released + 20, "phase-less trackpad has no momentum");
        gesture(18, true);
        released = y();
        QTest::qWait(130);
        check(y() < released - 20, "reversing the gesture did not reverse momentum");
        stop();

        viewport->setProperty("contentY", 500);
        wheel(0, -120, Qt::NoScrollPhase);
        QTest::qWait(35);
        check(y() > 500 && y() < 580, "mouse wheel was not animated");
        QTest::qWait(250);
        check(std::abs(y() - 580) < 2, "mouse wheel unexpectedly flings");

        viewport->setProperty("contentY", 1000);
        wheel(0, 0, Qt::ScrollBegin);
        for (int i = 0; i < 6; ++i) wheel(-18, 0, Qt::ScrollUpdate);
        for (int delta : {-12, -8, -4, -2, -1, -1, -1, -1, -1}) wheel(delta, 0, Qt::ScrollMomentum);
        wheel(0, 0, Qt::ScrollEnd);
        released = y();
        QTest::qWait(200);
        check(std::abs(y() - released) < 2, "OS momentum was doubled");

        wheel(0, 0, Qt::ScrollBegin);
        for (int i = 0; i < 6; ++i) wheel(-18, 0, Qt::ScrollUpdate);
        for (int i = 0; i < 4; ++i) wheel(-14, 0, Qt::ScrollMomentum);
        wheel(0, 0, Qt::ScrollEnd);
        released = y();
        QTest::qWait(200);
        check(std::abs(y() - released) < 2, "abrupt native momentum end caused a second fling");
        gesture(-18, true);
        released = y();
        QTest::qWait(130);
        check(y() > released + 20, "native momentum flag leaked into next finger gesture");
        stop();

        viewport->setProperty("contentY", 1);
        gesture(40, true);
        QTest::qWait(250);
        check(std::abs(y()) < 1, "scroll escapes top bound");
        double end = viewport->property("contentHeight").toDouble() - viewport->height();
        viewport->setProperty("contentY", end - 1);
        gesture(-40, true);
        QTest::qWait(250);
        check(std::abs(y() - end) < 1, "scroll escapes bottom bound");

        viewport->setProperty("contentY", 1000);
        gesture(-18, true);
        stop();
        viewport->setProperty("contentHeight", 100);
        viewport->setProperty("contentY", 0);
        gesture(-18, true);
        QTest::qWait(250);
        check(std::abs(y()) < 1, "short content scrolls out of bounds");
        std::cout << "PASS: pixel scrolling with/without phases, release momentum, reversal, click interruption, eased wheel and bounds" << std::endl;
    } catch (const std::exception &error) {
        std::cerr << "FAIL: " << error.what() << " (contentY=" << y() << ")" << std::endl;
        return 1;
    }
    return 0;
}
