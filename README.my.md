# PHP Runtime Security Checker

Ubuntu server များရှိ PHP runtime package များကို စစ်ဆေးရန် Bash CLI ဖြစ်သည်။
CVE-2026-109618 နှင့် CVE-2026-109619 ကိုသာ စစ်ဆေးပြီး server တစ်ခုလုံး
လုံခြုံကြောင်း အာမခံခြင်း မပြုပါ။

Bash 4.4+၊ Ubuntu 22.04 / 24.04 / 26.04၊ amd64 / arm64၊ APT၊ dpkg နှင့်
systemd လိုအပ်သည်။ Composer၊ Node.js၊ Python မလိုအပ်ပါ။

## ထည့်သွင်းခြင်းနှင့် အသုံးပြုခြင်း

```sh
git clone https://github.com/USERNAME/php-runtime-security-checker.git
cd php-runtime-security-checker
bash bin/php-security-check --check
bash bin/php-security-check --json
bash bin/php-security-check --output report.txt --no-color
sudo bash bin/php-security-check --fix
sudo bash bin/php-security-check --fix --yes
sudo bash bin/php-security-check --restart
```

USERNAME သည် နမူနာသာ ဖြစ်ပြီး အမှန်တကယ် repository ပိုင်ရှင်ဖြင့် အစားထိုးပါ။
မူလ mode သည် ဖတ်ရှုစစ်ဆေးခြင်းသာ ဖြစ်သည်။ စစ်ဆေးရန် root မလိုပါ။
ပြုပြင်ခြင်းတွင် အပြောင်းအလဲကို ကြိုပြပြီး အတည်ပြုချက်တောင်းသည်။ `--yes`
သည် မေးခွန်းကိုသာ ကျော်ပြီး safety check များကို ဆက်လုပ်သည်။
`--output` သည် ရှိပြီးသား file ကို မရေးထပ်ပါ။

## ရလဒ်များ

- PASS / exit 0: သတ်မှတ်ထားသည့် package နှင့် CVE အထောက်အထား ပြည့်စုံသည်။
- FAIL / exit 1: အတည်ပြုထားသည့် Ubuntu mapping အရ patch မပြည့်စုံပါ။
- UNKNOWN / exit 2: package origin၊ backport သို့မဟုတ် restart အထောက်အထား မလုံလောက်ပါ။
- ERROR / exit 3: command၊ package operation သို့မဟုတ် report ရေးခြင်း မအောင်မြင်ပါ။

PHP upstream fixed version များမှာ 8.2.35၊ 8.3.36၊ 8.4.27၊ 8.5.12 ဖြစ်သည်။
Ubuntu vendor backport ကို version နံပါတ်ဟောင်းဖြစ်ရုံဖြင့် vulnerable ဟု
မသတ်မှတ်ပါ။ [အရင်းအမြစ်များ](data/SOURCES.md) ကို 2026-10-22 တွင်
စစ်ဆေးထားသည်။ မသိသော backport နှင့် custom build များကို UNKNOWN ပြသည်။
PHP 8.1 သည် upstream EOL ဖြစ်သော်လည်း Ubuntu 22.04 vendor fix ကို သိရှိသည်။

```text
Advisory: php8.3-fpm|CVE-2026-109618|PASS
Services: UNKNOWN
Reboot: REQUIRED
Overall: UNKNOWN
```

Package ကို patch လုပ်ထားသော်လည်း worker များ restart ပြီးကြောင်း မသိပါက
UNKNOWN ဖြစ်နိုင်သည်။ Reboot လိုအပ်ခြင်းကို သီးခြားပြသည်။

## လုံခြုံစွာ ပြုပြင်ခြင်း

Backup နှင့် maintenance အချိန်ကို ပြင်ဆင်ပြီး APT metadata ကို သီးခြား
`sudo apt-get update` ဖြင့် refresh လုပ်ပါ။ Tool သည် PHP branch မပြောင်း၊
repository မထည့်၊ package မဖျက်၊ autoremove / full-upgrade / dist-upgrade
မလုပ်၊ အလိုအလျောက် reboot မလုပ်ပါ။ Held package၊ အသစ်ထည့်ရမည့် dependency
နှင့် မသက်ဆိုင်သော update များကို ပိတ်ပင်သည်။ APT မအောင်မြင်ပါက
တစ်စိတ်တစ်ပိုင်း update ဖြစ်ပြီးသား ဖြစ်နိုင်သည်။

Apache configuration ကို စစ်ဆေးပြီး လက်ရှိ active ဖြစ်သော FPM / Apache
service ကို restart လုပ်သည်။ Inactive service ကို မစတင်ပါ။ ပြီးလျှင်
ပြန်လည် audit လုပ်သည်။ ယာယီ `/usr/sbin/policy-rc.d` ဖြင့် package script
restart ကို ထိန်းသည်။ ရှိပြီးသား policy ရှိလျှင် ရပ်သည်။ Power loss သို့မဟုတ်
SIGKILL ဖြစ်လျှင် ယာယီ file ကို စီမံသူက စစ်ဆေးဖယ်ရှားရန် လိုနိုင်သည်။
APT hook များသည် စီမံသူ၏ ထိန်းချုပ်မှုအောက်တွင် ဖြစ်သည်။

Docker၊ custom PHP၊ remote FPM၊ queue worker၊ Octane နှင့် application
package များသည် အပြည့်အဝ စစ်ဆေးနိုင်သည့် scope ပြင်ပဖြစ်သည်။ Active web
server ရှိလျှင် routing အပြည့်အစုံ မသက်သေပြနိုင်သောကြောင့် UNKNOWN ပြသည်။
CLI package ရှိခြင်းသည် application သုံးနေကြောင်း အထောက်အထား မဟုတ်ပါ။

## စမ်းသပ်ခြင်းနှင့် YouTube demo

```sh
bash -n bin/php-security-check lib/*.sh tests/*.sh
shellcheck -x bin/php-security-check lib/*.sh tests/*.sh
bash tests/run.sh
```

Test များတွင် privileged operation ကို mock သုံးသည်။ CI တွင် Ubuntu 22.04၊
24.04 ကို သုံးသည်။ 26.04 နှင့် arm64 ကို deployment စမ်းသပ်မှု ထပ်လုပ်ရန်
လိုအပ်သည်။ Ruby ကို JSON test အတွက်သာ သုံးပြီး runtime တွင် မလိုပါ။
Video တွင် disposable VM၊ `--help`၊ mocked test၊ read-only report နှင့်
UNKNOWN အဓိပ္ပာယ်ကို ပြပါ။ Secret၊ application data နှင့် production
configuration ကို မပြပါနှင့်။ အသေးစိတ်ကန့်သတ်ချက်များကို English
[README](README.md) တွင် ဖတ်နိုင်သည်။ MIT license ဖြစ်သည်။
