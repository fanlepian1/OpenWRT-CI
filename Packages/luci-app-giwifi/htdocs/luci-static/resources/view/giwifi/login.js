'use strict';
'require view';
'require form';

return view.extend({
	render: function() {
		var m, s, o;

		m = new form.Map('giwifi', _('GIWIFI 校园网自动登录'),
			_('定时检测联网状态，掉线后自动用帐号密码重新认证 GIWIFI 校园网。'));

		s = m.section(form.NamedSection, 'login', 'giwifi', _('登录设置'));
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('启用自动登录'));
		o.default = '0';
		o.rmempty = false;

		o = s.option(form.Value, 'username', _('帐号'));
		o.placeholder = '学号 / 手机号';
		o.rmempty = false;

		o = s.option(form.Value, 'password', _('密码'));
		o.password = true;
		o.rmempty = false;

		o = s.option(form.Value, 'gateway', _('认证门户地址'),
			_('学校 GIWIFI 门户地址，例如 http://100.100.9.2'));
		o.placeholder = 'http://100.100.9.2';
		o.datatype = 'url';

		o = s.option(form.Value, 'key', _('AES 密钥'),
			_('门户前端使用的 16 字节密钥，默认 1234567887654321，不同学校可能不同。'));
		o.placeholder = '1234567887654321';

		o = s.option(form.Value, 'check_url', _('联网检测地址'),
			_('返回 200 或 204 时认为已联网。'));
		o.placeholder = 'http://connect.rom.miui.com/generate_204';

		o = s.option(form.Value, 'interval', _('检测间隔（秒）'),
			_('在线状态下每隔多少秒检测一次，默认 300 秒。'));
		o.datatype = 'uinteger';
		o.placeholder = '300';

		o = s.option(form.Value, 'user_agent', _('User-Agent'),
			_('部分学校门户会校验 UA，一般保持默认即可。'));
		o.placeholder = 'Mozilla/5.0 ...';

		return m.render();
	}
});
