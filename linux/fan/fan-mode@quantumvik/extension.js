// Quick Settings "Fan" toggle: Auto / Quiet / Max Cooling, backed by /usr/local/sbin/fan-mode.
// Clicking the toggle switches between Auto and the last other mode you picked (Max at first).
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';

const HELPER = '/usr/local/sbin/fan-mode';
const ICON = 'weather-windy-symbolic';
const MODES = {
    auto: {label: 'Auto', hint: 'Firmware fan curve'},
    quiet: {label: 'Quiet', hint: 'Turbo off, CPU capped at 10 W'},
    max: {label: 'Max Cooling', hint: 'Fan at full speed'},
};

function run(argv) {
    return new Promise((resolve, reject) => {
        const proc = Gio.Subprocess.new(argv,
            Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
        proc.communicate_utf8_async(null, null, (p, res) => {
            try {
                const [, stdout, stderr] = p.communicate_utf8_finish(res);
                if (p.get_successful())
                    resolve(stdout.trim());
                else
                    reject(new Error(stderr.trim() || `${argv.join(' ')} failed`));
            } catch (e) {
                reject(e);
            }
        });
    });
}

// "mode=auto rpm=0 temp=63" -> {mode: 'auto', rpm: '0', temp: '63'}
const parse = line => Object.fromEntries(line.split(' ').map(kv => kv.split('=')));

const FanToggle = GObject.registerClass(
class FanToggle extends QuickMenuToggle {
    _init(indicator) {
        super._init({title: 'Fan', iconName: ICON});
        this._indicator = indicator;
        this._mode = 'auto';
        this._lastOther = 'max';
        this._pollId = 0;

        this.menu.setHeader(ICON, 'Fan Mode');
        this._items = {};
        for (const [mode, {label}] of Object.entries(MODES)) {
            const item = new PopupMenu.PopupMenuItem(label);
            item.connect('activate', () => this._setMode(mode));
            this.menu.addMenuItem(item);
            this._items[mode] = item;
        }
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._info = new PopupMenu.PopupMenuItem('', {reactive: false});
        this.menu.addMenuItem(this._info);

        this.connect('clicked', () => this._setMode(this._mode === 'auto' ? this._lastOther : 'auto'));
        this.menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                this._startPolling();
            else
                this._stopPolling();
        });
        this.connect('destroy', () => this._stopPolling());

        this._refresh();
    }

    async _refresh() {
        try {
            this._sync(parse(await run([HELPER, 'status'])));
        } catch (e) {
            this.subtitle = 'Unavailable';
            this._info.label.text = e.message;
        }
    }

    _sync({mode, rpm, temp}) {
        this._mode = MODES[mode] ? mode : 'auto';
        if (this._mode !== 'auto')
            this._lastOther = this._mode;
        this.checked = this._mode !== 'auto';
        this.subtitle = MODES[this._mode].label;
        this._indicator.visible = this.checked;
        for (const [m, item] of Object.entries(this._items))
            item.setOrnament(m === this._mode ? PopupMenu.Ornament.CHECK : PopupMenu.Ornament.NONE);
        this._info.label.text = `${MODES[this._mode].hint} · ${rpm} RPM · CPU ${temp}°C`;
    }

    async _setMode(mode) {
        try {
            this._sync(parse(await run(['pkexec', HELPER, mode])));
        } catch (e) {
            Main.notifyError('Fan mode not changed', e.message);
            this._refresh();
        }
    }

    _startPolling() {
        this._refresh();
        this._pollId ||= GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
            this._refresh();
            return GLib.SOURCE_CONTINUE;
        });
    }

    _stopPolling() {
        if (this._pollId)
            GLib.source_remove(this._pollId);
        this._pollId = 0;
    }
});

const FanIndicator = GObject.registerClass(
class FanIndicator extends SystemIndicator {
    _init() {
        super._init();
        // Top-bar icon, shown only while the fan is not on Auto.
        const icon = this._addIndicator();
        icon.iconName = ICON;
        icon.visible = false;
        this.quickSettingsItems.push(new FanToggle(icon));
    }
});

export default class FanModeExtension extends Extension {
    enable() {
        this._indicator = new FanIndicator();
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
    }

    disable() {
        this._indicator.quickSettingsItems.forEach(item => item.destroy());
        this._indicator.destroy();
        this._indicator = null;
    }
}
