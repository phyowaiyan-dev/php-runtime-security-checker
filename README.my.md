# PHP Runtime Security Checker

Laravel အပါအဝင် PHP application များနှင့် သက်ဆိုင်သည့် PHP runtime CVE
နှစ်ခုကိုသာ စစ်ဆေးသော read-only tool ဖြစ်သည်။

- CVE-2026-109618
- CVE-2026-109619

**Installed PHP package များကိုသာ စစ်သည်။** Laravel/Composer dependency၊
application code၊ Apache handler နှင့် worker များ၏ loaded PHP ကို မစစ်ပါ။

## အသုံးပြုနည်း

Ubuntu 22.04 / 24.04 / 26.04၊ amd64 / arm64၊ Bash 4.4+၊ dpkg နှင့် apt-cache
လိုအပ်သည်။ Root၊ Composer၊ Python၊ Node.js နှင့် network request မလိုပါ။

```bash
git clone https://github.com/phyowaiyan-dev/php-runtime-security-checker.git
cd php-runtime-security-checker
bash bin/php-security-check --check
bash bin/php-security-check --json
bash bin/php-security-check --output report.txt
```

မူလ mode သည် `--check` ဖြစ်သည်။ `--help`၊ `--version`၊ `--no-color` ကိုလည်း
သုံးနိုင်သည်။ ရှိပြီးသား output file ကို မရေးထပ်ပါ။

## နမူနာ Report

Package version နှင့် local APT metadata ရှိ PPA origin ကို အတည်ပြုနိုင်ပါက:

```text
PHP Runtime Security Checker v1.1.0
OS: Ubuntu 24.04.5 LTS (amd64)
PHP CLI: 8.4.27-1+ubuntu24.04.1+deb.sury.org+1
PHP FPM: 8.4.27-1+ubuntu24.04.1+deb.sury.org+1
CVE-2026-109618: PASS
CVE-2026-109619: PASS
Overall: PASS (PHP package checks)
Scope: Installed PHP packages only; Laravel dependencies and running workers are not checked.
```

CVE တစ်ခုစီကို တစ်ကြိမ်သာ အနှစ်ချုပ်ပြသည်။ JSON တွင် package တစ်ခုချင်းစီ၏
version၊ origin နှင့် CVE ရလဒ်ပါသည်။ Apache handler၊ service၊ reboot နှင့်
ထပ်ခါထပ်ခါ generic warning များ မပြတော့ပါ။ Package mapping မသေချာပါက
package တစ်ခုအတွက် note တစ်ကြိမ်သာ ပြသည်။

| Result / exit | အဓိပ္ပာယ် |
| --- | --- |
| PASS / 0 | သတ်မှတ်ထားသော CVE နှစ်ခုအတွက် installed package baseline ပြည့်စုံသည် |
| FAIL / 1 | အတည်ပြုထားသော Ubuntu vendor fix ထက် package ဟောင်းနေသည် |
| UNKNOWN / 2 | Origin၊ backport၊ platform သို့မဟုတ် PHP inventory အထောက်အထား မလုံလောက်ပါ |
| ERROR / 3 | Command၊ package query သို့မဟုတ် report ရေးခြင်း မအောင်မြင်ပါ |

Ubuntu backport ကို documented revision နှင့် နှိုင်းယှဉ်သည်။ သိရှိသော PPA
package ကို upstream fixed version နှင့် နှိုင်းယှဉ်သည်။ Unknown origin နှင့်
မသိသော backport ကို ခန့်မှန်းပြီး PASS မပေးပါ။ Binary အကြောင်းအရာကို သီးခြား
အတည်ပြုခြင်း မလုပ်ပါ။ [Source နှင့် verification date](data/SOURCES.md) ကို ကြည့်ပါ။

## လုံခြုံရေးနှင့် Scope

Version 1.1 တွင် `--fix`၊ `--restart`၊ `--yes` နှင့် service/handler inspection
ကို ဖယ်ရှားထားသည်။ Package update၊ service restart၊ PHP execution နှင့်
application secret ဖတ်ခြင်း မလုပ်ပါ။

PASS သည် CVE နှစ်ခုအတွက် installed PHP package စစ်ဆေးချက်သာ ဖြစ်ပြီး Laravel၊
server တစ်ခုလုံး၊ container၊ custom PHP သို့မဟုတ် worker များ လုံခြုံကြောင်း
အာမခံခြင်း မဟုတ်ပါ။ Package update လုပ်ပြီးနောက် လိုအပ်သော PHP-FPM၊ Apache
နှင့် Laravel worker restart ကို စီမံသူက သီးခြား ဆောင်ရွက်ရမည်။

## စမ်းသပ်ခြင်း

```bash
for file in bin/php-security-check lib/*.sh tests/*.sh examples/*.sh; do
    bash -n "$file" || exit
done
shellcheck -x bin/php-security-check lib/*.sh tests/*.sh examples/*.sh
bash tests/run.sh
```

Test များသည် fixture ကို သုံးပြီး real upgrade/restart မလုပ်ပါ။ CI ၏ JSON test
အတွက်သာ Ruby လိုအပ်သည်။ Runtime တွင် မလိုပါ။ macOS version comparator သည်
fixture အတွက်သာ ဖြစ်ပြီး Ubuntu CI တွင် real dpkg ကို သုံးသည်။
အသေးစိတ်ကို [English README](README.md) တွင် ဖတ်နိုင်သည်။ MIT license ဖြစ်သည်။
