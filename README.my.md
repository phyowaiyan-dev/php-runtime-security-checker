# PHP Runtime Security Checker

PHP ကို စစ်ဆေး၊ လိုအပ်သော patch ကို အတည်ပြုပြီး ထည့်သွင်း၊ ပြန်စစ်နိုင်သည့်
**command တစ်ခုတည်း** ပါသော terminal tool ဖြစ်သည်။ Laravel နှင့် အခြား PHP
application များ၏ runtime နှင့်သက်ဆိုင်သော CVE-2026-109618၊ CVE-2026-109619
နှစ်ခုကိုသာ အဓိက စစ်ဆေးသည်။

## စတင်အသုံးပြုရန်

```bash
git clone https://github.com/phyowaiyan-dev/php-runtime-security-checker.git
cd php-runtime-security-checker
bash bin/php-security-check
```

Bash 4.4+၊ Ubuntu 22.04 / 24.04 / 26.04၊ amd64 / arm64၊ dpkg၊ APT နှင့်
standard Ubuntu utility များ လိုအပ်သည်။ FPM/Apache guided repair အတွက် systemd
လိုအပ်သည်။ ပုံမှန် user ဖြင့် စတင်နိုင်ပြီး repair အတည်ပြုပြီးမှ sudo ကို တောင်းမည်။
ယုံကြည်စိတ်ချရသော local checkout ကိုသာ သုံးပါ။ Composer၊ Python၊ Node.js မလိုပါ။

## တစ်ကြိမ် အတည်ပြုရုံဖြင့် Check → Fix → Check

1. OS၊ installed PHP runtime နှင့် CVE နှစ်ခုကို စစ်သည်။
2. Repair လုပ်နိုင်ပါက update scope အတွင်းရှိ PHP package များ၊ local metadata ဖြင့်
   သိရှိနိုင်သော candidate version နှင့် restart လုပ်မည့် active service များကို ပြသည်။
3. `1` / `yes` ဖြင့် scope အတွင်းရှိ လုပ်ငန်းစဉ်အားလုံးကို ခွင့်ပြုနိုင်သည်။ `0` / `no`
   သို့မဟုတ် Enter ဖြင့် မပြောင်းလဲဘဲ ထွက်နိုင်သည်။ မှားရိုက်လျှင် ပြန်မေးမည်။ Sudo
   password သီးခြား တောင်းနိုင်သည်။
4. APT metadata refresh လုပ်ပြီး final verified plan ကို ပြသည်။ Simulation စစ်ပြီး
   ခွင့်ပြုထားသော PHP package များကိုသာ update လုပ်ကာ configuration စစ်ပြီး restart လုပ်သည်။
5. ပြီးလျှင် အလိုအလျောက် ပြန်စစ်ပြီး နောက်ဆုံး report ကို ပြသည်။ ဒုတိယ confirmation မမေးပါ။

Refresh ပြီးနောက် candidate version ပြောင်းနိုင်သော်လည်း အတည်ပြုထားသော
package/service scope ကို မချဲ့ပါ။ အပြင်ဘက်ပြောင်းလဲမှု လိုအပ်လျှင် ရပ်သည်။ Patch
ပြည့်စုံပြီးသားစနစ်တွင် root၊ metadata refresh နှင့် restart မလိုဘဲ ပြီးဆုံးသည်။

```text
PHP Runtime Security Checker  1.2.0
  Ubuntu 24.04.5 LTS  |  amd64
  ------------------------------------------------------------
  php8.4-cli                8.4.27-1+ubuntu24.04.1+deb.sury.org+1
  php8.4-fpm                8.4.27-1+ubuntu24.04.1+deb.sury.org+1

  CVE-2026-109618           PASS
  CVE-2026-109619           PASS
  Package result            PASS
  No package fix needed for these two CVEs.
```

```text
Refresh, apply verified PHP patches and restart the listed services?
  [1] Continue    [0] No / exit
  Choice [0]:
```

Terminal တွင် status အရောင်များ အလိုအလျောက်ပြသည်။ `NO_COLOR` သို့မဟုတ်
`--no-color` ဖြင့် ပိတ်နိုင်သည်။ Redirect လုပ်လျှင် plain text ဖြစ်သည်။
`--check` သည် read-only ဖြစ်ပြီး `--fix` သည် guided flow အတူတူ ဖြစ်သည်။
`--help`၊ `--version` လည်း ရှိသည်။ JSON၊ export၊ standalone restart နှင့်
အတည်ပြုချက်မလိုသော `--yes` မပါပါ။ Piped/noninteractive input ဖြင့် repair
ခွင့်မပြုနိုင်ဘဲ report သာ ပြသည်။

## ရလဒ်နှင့် Error Handling

| Result / exit | အဓိပ္ပာယ် |
| --- | --- |
| PASS / 0 | CVE နှစ်ခုအတွက် installed package baseline ပြည့်စုံသည် |
| FAIL / 1 | အတည်ပြုထားသော Ubuntu vendor fix ထက် package ဟောင်းနေသည် |
| UNKNOWN / 2 | Origin၊ backport၊ platform သို့မဟုတ် PHP version အထောက်အထား မလုံလောက်ပါ |
| ERROR / 3 | Check၊ sudo authorization၊ APT၊ config validation သို့မဟုတ် restart မအောင်မြင်ပါ |

Repair ပယ်ဖျက်လျှင် မူလ check ရလဒ်ကို ထိန်းထားသည်။ တစ်စိတ်တစ်ပိုင်း update
အောင်မြင်သော်လည်း operation မအောင်မြင်ပါက PASS မပေးဘဲ ERROR ပြသည်။

- **Old/EOL PHP:** Ubuntu vendor backport ကို အတည်ပြုနိုင်ပါက အသိအမှတ်ပြုသည်။
  မရှိလျှင် manual migration လမ်းညွှန်ပြပြီး PHP branch ကို အလိုအလျောက် မပြောင်းပါ။
- **Patch မရှိသေးခြင်း:** Configured repository တွင် verified fixed candidate မရှိလျှင်
  ရှင်းပြပြီး ရပ်သည်။ Version ပိုသစ်ရုံဖြင့် fix ဟု မသတ်မှတ်ပါ။
- **Origin/backport မသေချာခြင်း:** ခန့်မှန်းပြီး vulnerable/PASS ဟု မပြပါ။ Installed
  version ၏ origin ပျောက်နေပါက consent ရပြီး verified Ubuntu/PPA candidate ဖြင့်
  update လုပ်နိုင်သော်လည်း သိရှိပြီးသား vendor origin ကို မပြောင်းပါ။
- **Held package၊ မပြီးသေးသော dpkg transaction၊ dependency အသစ်၊ unsupported OS၊
  unmanaged CGI:** အလိုအလျောက် အတင်းမပြင်ဘဲ အကြောင်းရင်းပြပြီး ရပ်သည်။

Ubuntu backport ကို documented Debian revision ဖြင့် နှိုင်းယှဉ်ပြီး PPA ကို
verified upstream baseline ဖြင့် စစ်သည်။ [Source နှင့် verification date](data/SOURCES.md)
ကို ကြည့်ပါ။ Binary အကြောင်းအရာကို သီးခြား cryptographic စစ်ဆေးခြင်း မလုပ်ပါ။

## Production Safety

Affected `phpX.Y` source မှ installed core package များကိုသာ update လုပ်သည်။
Third-party extension နှင့် မသက်ဆိုင်သော package များ မပါပါ။ Package အသစ်မထည့်၊
package မဖျက်၊ autoremove / full-upgrade / dist-upgrade မလုပ်၊ repository မထည့်၊
branch မပြောင်း၊ အလိုအလျောက် reboot မလုပ်ပါ။ Version ကို pin လုပ်ပြီး root
transaction တွင် simulation ထပ်စစ်သည်။ Repair လုပ်နေစဉ် အခြား package manager
သို့မဟုတ် APT configuration ကို မပြောင်းပါနှင့်။

Package script restart များကို ယာယီ `/usr/sbin/policy-rc.d` ဖြင့် နှောင့်နှေးစေသည်။
စီမံသူ၏ policy ရှိပြီးသားဖြစ်လျှင် မရေးထပ်ဘဲ repair ကို ပိတ်သည်။ Normal exit နှင့်
signal များတွင် ယာယီ file ကို ရှင်းသည်။ SIGKILL / power loss ဖြစ်လျှင် checker က
ဖန်တီးခဲ့သော ယာယီ file ဟုတ်ကြောင်း စစ်ပြီး စီမံသူက ရှင်းရန် လိုနိုင်သည်။ APT hook
နှင့် policy မလိုက်နာသော script များတွင် side effect ရှိနိုင်သည်။ Existing conffile
များကို ထိန်းထားသည်။ Automatic rollback မပါပါ။

Active FPM/Apache mod_php ကို install မတိုင်မီနှင့် restart မတိုင်မီ configtest
လုပ်သည်။ Inactive service ကို မစတင်ပါ။ Restart ပြီး MainPID အသစ်၊ monotonic
start time အသစ်နှင့် active state ကို စစ်သည်။ Active ဖြစ်ရုံဖြင့် အောင်မြင်ကြောင်း
မသတ်မှတ်ပါ။ Application health သို့မဟုတ် worker အားလုံး fresh ဖြစ်ကြောင်း
အာမခံခြင်း မဟုတ်ပါ။ Secret မပေါ်စေရန် configuration output ကို မပြပါ။ Error
ဖြစ်လျှင် local APT/dpkg သို့မဟုတ် systemd log ကို သီးခြား စစ်ဆေးပါ။

**Scope:** PHP CVE နှစ်ခုနှင့် installed package အထောက်အထားသာ ဖြစ်သည်။ Server
တစ်ခုလုံး၊ Laravel/Composer dependency၊ container/custom PHP၊ remote handler၊
Octane နှင့် ရှိပြီးသား queue worker များ လုံခြုံကြောင်း PASS က အာမမခံပါ။
Application worker restart ကို စီမံသူက သီးခြား ဆောင်ရွက်ရမည်။ Handler parser
နှင့် ထပ်ခါထပ်ခါ generic warning များ မပါပါ။

## Development

```bash
for file in bin/php-security-check lib/*.sh tests/*.sh examples/*.sh; do
    bash -n "$file" || exit
done
shellcheck -x bin/php-security-check lib/*.sh tests/*.sh examples/*.sh
bash tests/run.sh
```

Privileged call များကို mock သုံးပြီး real APT refresh/update/restart မလုပ်ပါ။
Ubuntu CI တွင် real dpkg version comparison ကို သုံးသည်။ macOS comparator သည်
fixture အတွက်သာ ဖြစ်သည်။ CI သည် Ubuntu 22.04/24.04 အတွက် ဖြစ်ပြီး live 26.04၊
arm64 နှင့် maintainer-script behavior ကို deployment မတိုင်မီ သီးခြား စစ်ရန်
လိုအပ်သည်။ YouTube demo ကို disposable VM/snapshot တွင်သာ ပြပါ။
အသေးစိတ်ကို [English README](README.md) တွင် ဖတ်နိုင်သည်။ MIT license ဖြစ်သည်။
