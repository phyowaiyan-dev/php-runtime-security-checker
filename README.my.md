# PHP Runtime Security Checker

Ubuntu Server များတွင် PHP Runtime Security Vulnerability များကို စစ်ဆေးပြီး Security Patch ပြုလုပ်နိုင်သည့် Open-Source Bash CLI Tool ဖြစ်ပါတယ်။

**စစ်ဆေးပေးနိုင်သော CVEs**

- CVE-2026-109618
- CVE-2026-109619

**Supported:** Ubuntu 22.04 / 24.04 / 26.04, PHP 8.x, Bash 4.4+ (amd64 / arm64)

## Installation

```bash
git clone https://github.com/phyowaiyan-dev/php-runtime-security-checker.git
cd php-runtime-security-checker
```

## အသုံးပြုနည်း

**1. PHP Security စစ်ဆေးရန်**

```bash
bash bin/php-security-check --check
```

**2. Security Updates ပြုလုပ်ရန်**

```bash
sudo bash bin/php-security-check --fix
```

**3. အတည်ပြုချက်မမေးဘဲ Update ပြုလုပ်ရန်**

```bash
sudo bash bin/php-security-check --fix --yes
```

**4. Apache / PHP-FPM Restart ပြုလုပ်ရန်**

```bash
sudo bash bin/php-security-check --restart
```

**5. JSON Report ထုတ်ရန်**

```bash
bash bin/php-security-check --json
```

## Security Check ရလဒ်များ

| Status | အဓိပ္ပာယ် |
| --- | --- |
| ✅ PASS | စစ်ဆေးထားသော CVE များအတွက် Patch ပြည့်စုံသည် |
| ❌ FAIL | Security Patch လိုအပ်သည် |
| ⚠️ UNKNOWN | အချက်အလက်မလုံလောက်၍ ထပ်မံစစ်ဆေးရန်လိုသည် |
| ❗ ERROR | စစ်ဆေးခြင်း သို့မဟုတ် Update ပြုလုပ်ခြင်း မအောင်မြင်ပါ |

**သတိပြုရန်:** Production Server တွင် `--fix` အသုံးမပြုမီ Backup/Snapshot ပြုလုပ်ပါ။ PASS ဖြစ်ခြင်းသည် Server တစ်ခုလုံး လုံခြုံကြောင်း အာမခံခြင်းမဟုတ်ပါ။

ပိုမိုအသေးစိတ်ကို [English README](README.md) နှင့် [Security Sources](data/SOURCES.md) တွင် ဖတ်ရှုနိုင်ပါတယ်။

**License:** MIT

## Services: UNKNOWN နှင့် Restart အထောက်အထား

ယခင် code သည် လက်ရှိ command အတွင်း `restarted` flag ရှိမှသာ restart
လုပ်ပြီးကြောင်း လက်ခံခဲ့သည်။ နောက်တစ်ကြိမ် audit လုပ်လျှင် flag ပျောက်သဖြင့်
အပြင်မှ အောင်မြင်စွာ restart လုပ်ထားသော်လည်း UNKNOWN ပြနေခဲ့သည်။ Active
Apache/Nginx ကို handler မစစ်ဘဲ UNKNOWN သတ်မှတ်ခြင်းနှင့် ပြုပြင်မတိုင်မီ
warning များ ကျန်နေခြင်းကိုလည်း ပြင်ဆင်ထားသည်။

ယခု report တွင် အောက်ပါ အထောက်အထားနှစ်မျိုးကို သီးခြားပြသည်။

- **Restart freshness** — process များသည် package/config အပြောင်းအလဲပြီးမှ
  စတင်ထားကြောင်း စစ်ဆေးခြင်း။
- **Web handler coverage** — Apache ၏ enabled configuration နှင့် VirtualHost
  override များရှိ PHP handler ကို စစ်ဆေးခြင်း။

နှစ်ခုလုံး PASS ဖြစ်မှ `Services: PASS` ဖြစ်သည်။ CVE package နှစ်ခု PASS
ဖြစ်သော်လည်း လိုအပ်သော အထောက်အထားမပြည့်စုံပါက `Overall: UNKNOWN` ဖြစ်မည်။
Reboot status ကို သီးခြားပြသည်။ Active ဖြစ်ရုံ၊ restart command အောင်မြင်ရုံဖြင့်
patched PHP ကို process က အသုံးပြုနေကြောင်း မသတ်မှတ်ပါ။

Systemd MainPID၊ process စတင်ချိန် wall-clock/monotonic timestamp နှင့် kernel
`/proc` process start time ကို တိုက်ဆိုင်စစ်ဆေးသည်။ Service ၏ cgroup v2 ထဲရှိ
process အားလုံးသည် dpkg installation metadata၊ package file နှင့် configuration
တို့၏ modification/change time ထက် နောက်ကျမှ စတင်ထားရမည်။ Symlink နှင့်
configuration directory ပြောင်းလဲချိန်ကိုပါ စစ်သည်။ ဤအချိန်များသည် local
filesystem အထောက်အထားဖြစ်ပြီး exact transaction log သို့မဟုတ် binary
cryptographic အာမခံချက် မဟုတ်ပါ။ အချိန်တူနေခြင်း၊ clock မကိုက်ခြင်း၊ metadata
မရှိခြင်း၊ worker များစစ်နေစဉ် ပြောင်းလဲခြင်းတို့တွင် UNKNOWN ပြမည်။

အပြင်မှ restart လုပ်ထားသည်ကိုလည်း အထောက်အထားပြည့်စုံပါက လက်ခံသည်။ PHP-FPM
executable ကို package နှင့် တိုက်ဆိုင်ပြီး Apache process များတွင် သက်ဆိုင်ရာ
PHP module ကို load လုပ်ထားကြောင်း စစ်သည်။ Deleted shared library ကို လက်မခံပါ။
OPcache ၏ anonymous `/dev/zero (deleted)` shared memory သည် code ဟောင်းကျန်နေခြင်း
အထောက်အထား မဟုတ်သဖြင့် ၎င်းကြောင့်သာ UNKNOWN မဖြစ်ပါ။

Apache enabled include tree နှင့် enabled VirtualHost အတွင်း `SetHandler`၊
mod_php နှင့် standard local Unix-socket FPM mapping ကို စစ်သည်။ Socket အမည်သာ
ကြည့်ခြင်းမဟုတ်ဘဲ audited FPM master က အမှန်တကယ် ဖွင့်ထားကြောင်း စစ်သည်။
TCP/remote FPM၊ dynamic handler၊ rewrite proxy၊ `.htaccess` handler override၊
custom launch/config၊ external FPM pool include၊ မဖတ်နိုင်သော configuration နှင့်
Nginx upstream များကို manual review လိုအပ်သည်။ Apache configuration syntax
အားလုံးကို နားလည်နိုင်သည့် parser မဟုတ်ပါ။

```text
Restart freshness: PASS
Web handler coverage: UNKNOWN
Services: UNKNOWN
Reboot: NO
Overall: UNKNOWN
```

ဤကဲ့သို့ restart အထောက်အထားပြည့်စုံပြီး handler မသေချာပါက FPM ကို ထပ် restart
လုပ်ရန် warning မပေးတော့ပါ။ **Web handler coverage unverified** ဟုပြပြီး enabled
VirtualHost နှင့် handler override ကို စစ်ရန် အကြံပြုသည်။ Restart အထောက်အထား
မရပါက **restart freshness unverified** ဟုပြမည်။ Package metadata နှင့် `/proc`
read permission ကို စစ်ပါ။ Root-owned process ကို ဖတ်ရန် လိုအပ်လျှင်
`sudo bash bin/php-security-check --check` ဖြင့် read-only audit ပြန်လုပ်နိုင်သည်။
၎င်းသည် package update သို့မဟုတ် restart မလုပ်ပါ။ Apache graceful reload သည်
worker ဟောင်းကျန်နိုင်သောကြောင့် process အားလုံး fresh ဖြစ်ကြောင်း သက်သေမဟုတ်ပါ။

JSON တွင် `services.status` အပြင် `services.freshness`၊
`services.handler_coverage` နှင့် `services.evidence` ပါဝင်သည်။
စမ်းသပ်ရန်:

```bash
for file in bin/php-security-check lib/*.sh tests/*.sh examples/*.sh; do
    bash -n "$file" || exit
done
shellcheck -x bin/php-security-check lib/*.sh tests/*.sh examples/*.sh
bash tests/run.sh
```

Test များသည် privileged operation မလုပ်ဘဲ mock နှင့် fixture ကို သုံးသည်။ Linux
တွင် `/proc` start-time parser ကို unprivileged process ဖြင့် ထပ်စစ်သည်။ Live
Ubuntu deployment စမ်းသပ်ခြင်းကို သီးခြားလုပ်ဆောင်ရန် လိုအပ်သည်။
