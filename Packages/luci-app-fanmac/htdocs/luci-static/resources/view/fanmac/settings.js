'use strict';
'require view';
'require form';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('fanmac', _('MAC 兜底（factory 丢失）'),
			_('京东云 BE6500/太乙 刷大分区后 factory 分区没了，nvmem 取不到 MAC，' +
			  '网口变成 00:00:00:00:00:00，内核会拒绝把端口加进 br-lan，导致有线没 IP、无线也起不来。' +
			  '本插件在 netifd 之前按「factory 分区 → 已保存值 → 派生」给各口写上合法 MAC。'));

		s = m.section(form.NamedSection, 'settings', 'fanmac', _('设置'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('启用'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Flag, 'wireless', _('同时给 Wi-Fi 接口写 macaddr'),
			_('hostapd 会用这个 MAC 起 AP，wifi 的 nvmem 取不到 MAC 时靠它兜底。'));
		o.default = '1';

		o = s.option(form.Flag, 'bridge', _('同时给 br-lan 写 macaddr'));
		o.default = '1';

		o = s.option(form.Value, 'lan_mac', _('LAN 基准 MAC'),
			_('留空=自动。lan1 用它，lan2 及之后依次 +1，Wi-Fi 接口从 +4 开始。'));
		o.placeholder = 'auto';
		o.datatype = 'macaddr';

		o = s.option(form.Value, 'wan_mac', _('WAN MAC'), _('留空=自动（factory 偏移 6，或 LAN+8）'));
		o.placeholder = 'auto';
		o.datatype = 'macaddr';

		o = s.option(form.DummyValue, '_state', _('当前持久化值'),
			_('自动值在首次启动时生成，保存在 /etc/fanmac.macs，重启不变。' +
			  '改了设置后执行 /etc/init.d/fanmac restart 生效（或直接重启）。'));
		o.rawhtml = true;
		o.cfgvalue = function() {
			return E('em', {}, _('/etc/fanmac.macs / 日志：logread -e fanmac'));
		};

		return m.render();
	}
});
