/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include "vlc_stub_modules.hpp"

#include <QTest>
#include <QSignalSpy>

#include "dialogs/settings/config_option.hpp"
#include "dialogs/settings/hotkeys_model.hpp"

#include <vlc_configuration.h>

/* ConfigOption and HotkeysModel against the real core configuration.
 * Nothing is saved: the configuration file is never written here. */
class TestSettingsModel : public QObject
{
    Q_OBJECT

private:
    static bool hasChoice(ConfigOption& opt, const QVariant& value)
    {
        for (const QVariant& c : opt.choices())
            if (c.toMap().value("value") == value)
                return true;
        return false;
    }

private slots:
    void initTestCase()
    {
        m_env = std::make_unique<VLCTestingEnv>();
        QVERIFY(m_env->init());
    }

    void cleanupTestCase()
    {
        m_env.reset();
    }

    void testBool()
    {
        ConfigOption opt("fullscreen");
        QVERIFY(opt.available());
        QCOMPARE(opt.type(), ConfigOption::Bool);
        QVERIFY(!opt.text().isEmpty());
        QCOMPARE(opt.defaultValue(), QVariant(false));
        QVERIFY(!opt.hasRange());

        QSignalSpy valueSpy(&opt, &ConfigOption::valueChanged);
        QSignalSpy editedSpy(&opt, &ConfigOption::edited);
        const bool initial = opt.value().toBool();

        opt.setValue(!initial);
        QCOMPARE(opt.value().toBool(), !initial);
        QCOMPARE(bool(config_GetInt("fullscreen")), !initial);
        QCOMPARE(valueSpy.count(), 1);
        QCOMPARE(editedSpy.count(), 1);

        // a second option on the same name sees the change
        ConfigOption other("fullscreen");
        QCOMPARE(other.value().toBool(), !initial);

        opt.reset();
        QCOMPARE(opt.value(), QVariant(false));
        QVERIFY(!opt.modified());
        config_PutInt("fullscreen", initial);
    }

    void testInt()
    {
        ConfigOption opt("input-repeat");
        QVERIFY(opt.available());
        QCOMPARE(opt.type(), ConfigOption::Int);
        QVERIFY(opt.hasRange());
        QCOMPARE(opt.min().toLongLong(), 0);
        QCOMPARE(opt.max().toLongLong(), 65535);
        QVERIFY(opt.choices().isEmpty());

        const qint64 initial = opt.value().toLongLong();
        opt.setValue(42);
        QCOMPARE(opt.value().toLongLong(), 42);
        QCOMPARE(config_GetInt("input-repeat"), 42);
        QVERIFY(opt.modified());

        // QML may hand doubles and strings
        opt.setValue(7.0);
        QCOMPARE(opt.value().toLongLong(), 7);
        opt.setValue(QStringLiteral("8"));
        QCOMPARE(opt.value().toLongLong(), 8);

        // the core clamps to the range
        opt.setValue(1000000);
        QCOMPARE(opt.value().toLongLong(), 65535);

        opt.setValue(initial);
    }

    void testIntChoices()
    {
        ConfigOption opt("deinterlace");
        QVERIFY(opt.available());
        QCOMPARE(opt.type(), ConfigOption::Int);
        const QVariantList choices = opt.choices();
        QCOMPARE(choices.size(), 3);
        QVERIFY(hasChoice(opt, QVariant::fromValue<qint64>(-1)));
        QVERIFY(!choices[0].toMap().value("text").toString().isEmpty());

        const qint64 initial = opt.value().toLongLong();
        QSignalSpy indexSpy(&opt, &ConfigOption::currentIndexChanged);
        const int target = (opt.currentIndex() + 1) % choices.size();
        opt.setCurrentIndex(target);
        QCOMPARE(opt.currentIndex(), target);
        QCOMPARE(opt.value(), choices[target].toMap().value("value"));
        QVERIFY(indexSpy.count() >= 1);
        QCOMPARE(opt.textForValue(opt.value()), choices[target].toMap().value("text").toString());

        opt.setValue(initial);
    }

    void testFloat()
    {
        ConfigOption opt("rate");
        QVERIFY(opt.available());
        QCOMPARE(opt.type(), ConfigOption::Float);
        QCOMPARE(opt.defaultValue().toDouble(), 1.0);

        const double initial = opt.value().toDouble();
        opt.setValue(1.5);
        QCOMPARE(opt.value().toDouble(), 1.5);
        QCOMPARE(config_GetFloat("rate"), 1.5f);
        opt.setValue(QStringLiteral("0.75")); // C locale
        QCOMPARE(opt.value().toDouble(), 0.75);
        opt.setValue(initial);
    }

    void testString()
    {
        ConfigOption opt("snapshot-prefix");
        QVERIFY(opt.available());
        QCOMPARE(opt.type(), ConfigOption::String);
        QCOMPARE(opt.defaultValue().toString(), QStringLiteral("vlcsnap-"));

        const QString initial = opt.value().toString();
        const QString unicode = QStringLiteral("snap-é中-");
        opt.setValue(unicode);
        QCOMPARE(opt.value().toString(), unicode);
        char* psz = config_GetPsz("snapshot-prefix");
        QCOMPARE(QString::fromUtf8(psz), unicode);
        free(psz);

        // empty strings are stored as NULL by the core
        opt.setValue(QString());
        QCOMPARE(opt.value().toString(), QString());
        QVERIFY(config_GetPsz("snapshot-prefix") == nullptr);

        opt.reset();
        QCOMPARE(opt.value().toString(), QStringLiteral("vlcsnap-"));
        opt.setValue(initial);

        ConfigOption dir("snapshot-path");
        QVERIFY(dir.available());
        QCOMPARE(dir.type(), ConfigOption::Directory);

        ConfigOption key("key-play");
        QVERIFY(key.available());
        QCOMPARE(key.type(), ConfigOption::Key);
        QVERIFY(key.requiresRestart());
    }

    void testModule()
    {
        ConfigOption opt("aout");
        QVERIFY(opt.available());
        QCOMPARE(opt.type(), ConfigOption::Module);
        const QVariantList choices = opt.choices();
        QVERIFY(choices.size() > 2);
        QCOMPARE(choices.first().toMap().value("value").toString(), QStringLiteral("any"));
        QCOMPARE(choices.last().toMap().value("value").toString(), QStringLiteral("none"));
        QVERIFY(hasChoice(opt, QStringLiteral("adummy")));

        const QString initial = opt.value().toString();
        opt.setValue(QStringLiteral("adummy"));
        QCOMPARE(opt.value().toString(), QStringLiteral("adummy"));
        QVERIFY(opt.currentIndex() > 0);
        opt.setValue(initial);
    }

    void testModuleList()
    {
        ConfigOption opt("audio-filter");
        QVERIFY(opt.available());
        QCOMPARE(opt.type(), ConfigOption::ModuleList);
        const QVariantList choices = opt.choices();
        QVERIFY(!choices.isEmpty());

        const QString initial = opt.value().toString();
        const QString first = choices.first().toMap().value("value").toString();
        opt.setValue(QString());
        opt.setListItem(first, true);
        QVERIFY(opt.hasListItem(first));
        QCOMPARE(opt.value().toString(), first);
        opt.setListItem(QStringLiteral("other"), true);
        QCOMPARE(opt.value().toString(), first + QStringLiteral(":other"));
        opt.setListItem(first, false);
        QCOMPARE(opt.value().toString(), QStringLiteral("other"));
        opt.setValue(initial);
    }

    void testUnavailable()
    {
        ConfigOption missing("this-option-does-not-exist");
        QVERIFY(!missing.available());
        QCOMPARE(missing.type(), ConfigOption::Unknown);
        QVERIFY(!missing.value().isValid());
        QVERIFY(missing.choices().isEmpty());
        missing.setValue(true); // no crash, no effect
        missing.reset();
        QVERIFY(!missing.modified());

        // removed options are still known to the core, but not available
        ConfigOption obsolete("skip-frames");
        QVERIFY(!obsolete.available());

        // not an option on any platform (the Windows UI language is stored
        // in the registry by the QWidget preferences)
        ConfigOption language("language");
        QVERIFY(!language.available());
    }

    void testHotkeys()
    {
        HotkeysModel model;
        QVERIFY(model.rowCount() > 50);

        const int play = model.indexOf("key-play");
        const int stop = model.indexOf("key-stop");
        QVERIFY(play >= 0 && stop >= 0);
        QCOMPARE(model.indexOf("global-key-play"), play);

        const QVariantMap playItem = model.get(play);
        QCOMPARE(playItem.value("name").toString(), QStringLiteral("key-play"));
        QVERIFY(!playItem.value("action").toString().isEmpty());
        QVERIFY(playItem.value("hasGlobal").toBool());

        const QString stopKey = model.data(model.index(stop), HotkeysModel::KeyListRole)
                                    .toStringList().value(0);
        QVERIFY(!stopKey.isEmpty());
        QCOMPARE(model.findConflict(stopKey, play), stop);

        QSignalSpy editedSpy(&model, &HotkeysModel::edited);

        // conflict: nothing changes without force
        QCOMPARE(model.setKey(play, stopKey), stop);
        QCOMPARE(editedSpy.count(), 0);
        QVERIFY(!model.get(play).value("keyList").toStringList().contains(stopKey));

        // forced: the key moves from stop to play
        QCOMPARE(model.setKey(play, stopKey, false, true), -1);
        QCOMPARE(model.get(play).value("keys").toString(), stopKey);
        QVERIFY(!model.get(stop).value("keyList").toStringList().contains(stopKey));
        char* psz = config_GetPsz("key-play");
        QCOMPARE(QString::fromUtf8(psz), stopKey);
        free(psz);
        QVERIFY(model.get(play).value("modified").toBool());

        model.clearKey(play);
        QCOMPARE(model.get(play).value("keys").toString(), QString());

        model.resetAll();
        QVERIFY(!model.get(play).value("modified").toBool());
        QVERIFY(!model.get(stop).value("modified").toBool());

        QCOMPARE(model.keyFromEvent(Qt::Key_A, Qt::ControlModifier | Qt::ShiftModifier),
                 QStringLiteral("Ctrl+Shift+a"));
        QCOMPARE(model.keyFromEvent(Qt::Key_Space, Qt::NoModifier), QStringLiteral("Space"));
        QCOMPARE(model.keyFromEvent(Qt::Key_Shift, Qt::ShiftModifier), QString());
        QCOMPARE(model.keyText(QStringLiteral("Space\tMedia Play Pause")),
                 QStringLiteral("Space, Media Play Pause"));
        QCOMPARE(model.keyText(QStringLiteral("Not A Key")), QStringLiteral("Not A Key"));
    }

private:
    std::unique_ptr<VLCTestingEnv> m_env;
};

QTEST_GUILESS_MAIN(TestSettingsModel)
#include "test_settings_model.moc"
