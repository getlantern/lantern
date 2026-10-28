# Translation style guides

`translate.py` sends the `common` section plus the locale's own section to both the
translator and the reviewer. Each rule below was checked against the strings already
in `assets/locales` on 2026-10-28, so a new translation matches what is shipped.
Where the existing files were inconsistent, the rule picks the majority form.

## common

### Product and audience

Lantern is a VPN and censorship-circumvention app. Many users are in countries where the internet is filtered and are under real pressure when they open the app. Tone is calm, clear, and trustworthy: plain statements, no marketing hype, no exclamation marks unless the English has one, no jokes. Address the user directly and respectfully in the register the language section specifies.

### What the strings are

Every string is a piece of UI: a button label, a screen title, a setting name, a short message, an error. The key tells you where it sits: suffixes like `_title`, `_body`, `_button`, `_hint`, `_error`, prefixes like `settings_`, `report_issue_`, `advanced_stats_`. A developer comment, when present, describes the exact spot. Use both.

- Buttons and menu items: short, in the form the language uses for actions in apps.
- Titles and labels: noun phrases, no trailing period.
- Messages: complete sentences. If the English ends with a period, end with the language's sentence mark.
- Keep length close to the English. Phone screens are narrow; a label that doubles in length gets clipped.

### Placeholders and formatting

- `%s` and `%d` are filled in by position at runtime. Keep every one, keep their order, keep the exact spelling. If the language wants a different word order, restructure the sentence around the placeholders instead of swapping them.
- `%d` is always a number and `%s` is text (a name, a count already formatted, a duration). There is no plural support, so avoid grammar that must agree with the number: prefer "Months earned: %s" style phrasing over forms that would be wrong for 1 versus 5.
- `\n` is a line break. Keep the same number of them.
- Do not attach grammatical suffixes or inflections directly to a placeholder. Put them on a surrounding word.
- Never translate URLs, email addresses, code, file formats (PNG, JPG), units (MB), or anything in the glossary.

### Terminology

- Glossary terms stay exactly as written, in Latin script: Lantern, Action Mode, VPN, platform and store names. The language section says if one has an accepted local form.
- "Pro" is the paid tier. "Lantern Pro" stays in Latin script. The language section says whether a standalone "Pro" ("Upgrade to Pro") stays Latin or takes the local form the existing strings use.
- Reuse the vocabulary of the existing translations you are shown. Consistency across the app matters more than a slightly better word.
- Common tech terms (server, network, connect, password, email, account, settings, update) use the established term in the language's app ecosystem, not a coined one.

### Output

Return the translated string and nothing else: no surrounding quotes, no notes inside the text, no alternatives, no transliteration in parentheses.

## ar

Arabic

- Modern Standard Arabic (الفصحى الحديثة) understandable from Morocco to Iraq. No dialect, no regional vocabulary.
- Address the user in the singular with the respectful neutral form used by Arabic apps. Pronouns are rarely written out; verbal nouns (المصدر) keep strings gender-neutral.
- Buttons and actions use the verbal noun, as the existing strings do: "اتصال", "قطع الاتصال", "إلغاء", "متابعة", "تسجيل الدخول", "حذف الحساب". Titles are noun phrases: "الإعدادات", "التالي".
- Digits: Western (0-9) everywhere. The existing strings contain no Arabic-Indic digits.
- Punctuation: Arabic comma "،", question mark "؟", semicolon "؛". Period "." as usual. Every English sentence that ends with a period ends with a period in Arabic.
- Spelling: hamza written correctly (إلى, أو, إعدادات), tāʾ marbūṭa "ة" versus "ه" and final "ي" versus "ى" distinguished. No tashkīl except to avoid real ambiguity.
- Latin glossary terms and placeholders sit inside the sentence as ordinary words with a space on each side. No direction-control characters.
- "Pro": "Lantern Pro" stays Latin. A standalone "Pro" is transliterated "برو" ("الترقية إلى برو"), matching the existing strings.
- Vocabulary: الخادم (server), الشبكة (network), كلمة المرور (password), البريد الإلكتروني (email), الحساب (account), الإعدادات (settings), الاشتراك (subscription), تحديث (update), اتصال (connection).
- Arabic runs about the same length as English here (median ratio 0.9); drop filler like "يرجى" unless the English says "please".

## fa

Persian (Iran)

- Iranian Persian, not Dari or Tajik. Vocabulary and phrasing as used in apps inside Iran.
- Address the user formally with "شما" and the polite plural imperative in sentences ("وارد شوید", "ذخیره کنید"). Never the singular "تو" as a pronoun.
- Buttons and labels use the noun form, as the existing strings do: "اتصال", "قطع اتصال", "لغو", "ادامه", "ورود", "تنظیمات", "بعدی". Messages use the polite plural verb.
- Script: Persian "ی" (U+06CC) and "ک" (U+06A9), never Arabic "ي" and "ك". The existing file is clean; keep it so. Zero-width non-joiner (U+200C) in compounds and verb prefixes: "می‌شود", "برنامه‌ها", "به‌روزرسانی".
- Digits: Persian digits (۰-۹) for counts in running text ("۳۰ روز", "تا ۵ دستگاه"), Western digits for technical values (15 MB, version 10, PNG), matching the existing split. Placeholders render Western digits on their own.
- Punctuation: Persian comma "،", question mark "؟", semicolon "؛". Period "." as usual.
- "Pro": "Lantern Pro" stays Latin. A standalone "Pro" is "پرو" ("ارتقا به نسخه پرو"), matching the existing strings.
- Prefer Persian words where they are the common app term: کاربر, رمز عبور, تنظیمات, اتصال, شبکه, به‌روزرسانی, اشتراک, حساب کاربری. Accept established loans: سرور, ایمیل, اینترنت.
- "Lantern" and "VPN" stay in Latin script. Do not write لنترن.

## ps

Pashto

- Standard Pashto as written in Afghanistan. Avoid Dari and Urdu phrasing where a Pashto form exists.
- Address the user with the respectful plural "تاسو" and matching verb forms. Buttons use the plural imperative as the existing strings do: "وصل کړئ", "قطع کړئ", "لغوه کړئ", "دوام ورکړئ", "حساب ړنګ کړئ". Labels are nouns: "تنظیمات", "ننوتل".
- Script: Pashto-specific letters must be the Pashto forms: ښ, ږ, څ, ځ, ڼ, ګ, ې, ۍ, ئ.
- Digits: Western (0-9), matching the existing strings.
- Punctuation: comma "،", question mark "؟". Period "." as usual.
- Verb goes last. Split a long English sentence into two if that reads more naturally.
- "Pro": "Lantern Pro" and a standalone "Pro" stay in Latin script, matching the majority of existing strings.
- Vocabulary: سرور (server), شبکه (network), پټنوم (password), بریښنالیک (email), حساب (account), تنظیمات (settings), اتصال (connection), تازه کول (update), ګډون (subscription).
- Few people will proofread Pashto, so prefer the simplest clear sentence over elegant variation.

## ur

Urdu (Pakistan)

- Standard Urdu as used in Pakistan, in Perso-Arabic script. Write plain Unicode; Nastaliq rendering is the font's job.
- Address the user with the respectful "آپ" and the polite imperative, as the sister file ur-in does: "منسلک کریں", "منقطع کریں", "منسوخ کریں", "جاری رکھیں", "سائن ان کریں". Labels are nouns: "ترتیبات", "اگلا". Never "تم" or "تو".
- Script: Urdu letter forms "ی", "ے", "ک", "ہ", "ھ", "ں", "ۓ". Not the Arabic "ي" or "ك".
- Digits: Western (0-9).
- Punctuation: Urdu full stop "۔" where the English has a period, comma "،", question mark "؟".
- Vocabulary follows Pakistani app usage, where English technical terms in Urdu script are standard: سرور, ای میل, پاس ورڈ, اکاؤنٹ, اپ ڈیٹ, کنکشن, سبسکرپشن. Settings is "ترتیبات". Use Urdu words where common: نیٹ ورک, ملک (country), زبان (language).
- "Pro": "Lantern Pro" and a standalone "Pro" stay in Latin script, matching the majority of existing Urdu strings.
- "Lantern" and "VPN" stay in Latin script. Do not write لینٹرن.
- Honorific verb forms make strings long; keep button labels to the shortest polite form.

## ur-in

Urdu (India)

- Standard Urdu as used in India, in Perso-Arabic script. Write plain Unicode; Nastaliq rendering is the font's job.
- Address the user with the respectful "آپ" and the polite imperative, matching the existing strings: "منسلک کریں", "منقطع کریں", "منسوخ کریں", "جاری رکھیں", "سائن ان کریں". Labels are nouns: "ترتیبات", "اگلا". Never "تم" or "تو".
- Script: Urdu letter forms "ی", "ے", "ک", "ہ", "ھ", "ں", "ۓ". The existing file is clean; keep it so.
- Digits: Western (0-9), matching the existing strings.
- Punctuation: Urdu full stop "۔" where the English has a period (the existing file does this consistently), comma "،", question mark "؟".
- Indian Urdu shares everyday vocabulary with Hindi; prefer the term an Indian Urdu speaker hears in a phone app over a Persianised literary form. English technical terms in Urdu script are standard: سرور, ای میل, پاس ورڈ, اکاؤنٹ, اپ ڈیٹ, کنکشن. Settings is "ترتیبات".
- "Pro": "Lantern Pro" and a standalone "Pro" stay in Latin script, matching the majority of existing strings.
- "Lantern" and "VPN" stay in Latin script. Do not write لینٹرن.
- Honorific verb forms make strings long; keep button labels to the shortest polite form.

## hi

Hindi

- Standard Hindi in Devanagari as used in Indian phone apps. Address the user formally with "आप" and the polite imperative, matching the existing strings: "कनेक्ट करें", "रद्द करें", "जारी रखें", "साइन इन करें". Never "तुम".
- Register: everyday Hindi, not Sanskritised. English technical terms in Devanagari are the norm: सर्वर, ऐप, ईमेल, पासवर्ड, अकाउंट, सेटिंग्स, अपडेट, कनेक्ट, डिस्कनेक्ट, नेटवर्क, सब्सक्रिप्शन. Hindi for ordinary words: देश, भाषा, साझा करें, हटाएं, अगला.
- Digits: Western (0-9), matching the existing strings.
- Punctuation: the danda "।" ends a sentence where the English has a period; the existing file does this almost without exception. Question mark "?" and comma "," as in English. Labels have no danda.
- Spelling: nukta where the loanword needs it (ज़, फ़), "ऑ" for the English short o (ऑप्शन, लॉग).
- "Pro": "Lantern Pro" stays Latin. A standalone "Pro" is "प्रो" ("प्रो में अपग्रेड करें"), matching the existing strings.
- Postpositions stay separate words after a placeholder ("%s के लिए"), never fused to it.
- "Lantern" and "VPN" stay in Latin script.

## bn

Bengali (Bangladesh)

- Standard colloquial Bengali as used in Bangladesh. Where Bangladesh and West Bengal differ, use the Bangladeshi term.
- Address the user formally with "আপনি" and the polite imperative, matching the existing strings: "সংযোগ করুন", "বাতিল করুন", "চালিয়ে যান", "সাইন ইন করুন". Never "তুমি".
- English technical terms in Bengali script are standard: সার্ভার, অ্যাপ, ইমেইল, পাসওয়ার্ড, অ্যাকাউন্ট, সেটিংস, আপডেট, নেটওয়ার্ক, সাবস্ক্রিপশন. Connect is "সংযোগ করুন". Bengali for ordinary words: দেশ, ভাষা, শেয়ার করুন, মুছুন, পরবর্তী.
- "VPN" is written "ভিপিএন" in Bengali script, matching the existing strings ("ভিপিএন সেটিংস"). "Lantern" stays Latin.
- Digits: Bengali digits (০-৯) for counts in running text ("৩০ দিন", "৫টি ডিভাইস"), Western digits for technical values (15 MB, version 10), matching the existing split.
- Punctuation: the daṛi "।" ends a sentence where the English has a period; the existing file does this consistently. Question mark "?" and comma "," as in English. Labels have no daṛi.
- "Pro": "Lantern Pro" stays Latin. A standalone "Pro" is "প্রো" ("প্রো-তে আপগ্রেড করুন"), matching the existing strings.
- Postpositions stay separate words after a placeholder ("%s এর জন্য"), never fused to it.

## zh-Hans

Chinese (Simplified)

- Simplified characters with mainland China vocabulary: 软件, 服务器, 网络, 登录, 账户, 设置, 隐私, 订阅, 更新, 连接, 断开连接, 密码, 电子邮件.
- Address the user with the formal "您", matching the existing strings (147 uses of 您 against 3 of 你).
- "Lantern" is written "蓝灯", the product's established Chinese name, matching almost every existing string ("蓝灯项目", "购买蓝灯 Pro"). "Lantern Pro" is "蓝灯 Pro". A standalone "Pro" is "专业版" ("升级至专业版").
- Full-width punctuation: ，。！？：；（）and “” for quotes. The existing file is mostly full-width; do not add new half-width punctuation.
- One space between Chinese characters and any Latin word, digit, or placeholder, matching the existing strings: "蓝灯 Pro", "仅支持 PNG、JPG 和 GIF 图片", "不超过 15 MB", "连接到 %s".
- Concise: Chinese UI text is short. Drop filler such as 请 unless the English says "please".
- Buttons use the verb form (登录, 保存, 取消, 连接, 继续); titles and settings use noun phrases (设置, 下一步, 服务器位置).
- Counts: a measure word is needed when a bare number precedes a noun ("%s 个"); pick the right one for the noun.
- Translate from the English directly, not by converting the Traditional file.

## zh-Hant

Chinese (Traditional, Taiwan)

- Traditional characters with Taiwan vocabulary, never a character conversion of the Simplified file. The words differ: 軟體 (not 软件), 伺服器 (not 服务器), 網路 (not 网络), 登入 (not 登录), 帳號 or 帳戶, 設定 (not 设置), 連線 (not 连接), 中斷連線, 密碼, 電子郵件, 資訊 (not 信息), 檔案 (not 文件).
- Address the user with "你", the majority form in the existing file (109 uses of 你 against 39 of 您). Do not switch to 您.
- "Lantern" stays in Latin script, as most existing strings do. "Lantern Pro" stays "Lantern Pro". A standalone "Pro" is "專業版" ("升級至專業版"). Never 蓝灯 or 燈籠.
- Every character must be Traditional. A dozen existing strings contain Simplified characters; do not imitate them.
- Full-width punctuation: ，。！？：；（）and 「」 for quotes.
- One space between Chinese characters and any Latin word, digit, or placeholder, matching the existing strings: "輸入您的 Lantern 帳戶", "不超過 15 MB", "連線至 %s".
- Concise: drop filler such as 請 unless the English says "please".
- Buttons use the verb form (登入, 儲存, 取消, 連線, 繼續); titles and settings use noun phrases (設定, 下一步, 伺服器位置).
- Counts: use the correct measure word when a bare number precedes a noun.

## es

Spanish (Latin America)

- Neutral Latin American Spanish that reads naturally from Mexico to Argentina. No Spain-specific vocabulary (no ordenador, móvil, vale, coger) and no voseo.
- Address the user informally with "tú", matching the existing strings (conéctate, ingresa, tu cuenta). The file contains no "usted"; keep it that way.
- Buttons use the infinitive, matching the existing strings: "Conectar", "Desconectar", "Cancelar", "Continuar", "Iniciar sesión", "Eliminar cuenta". Labels are nouns: "Configuración", "Siguiente", "Listo".
- Sentence case: only the first word and proper nouns capitalised ("Iniciar sesión", "Invitar amigos"). The file has some older Title Case labels; do not imitate them.
- Inverted punctuation is mandatory: ¿Olvidaste tu contraseña? ¡Listo! The existing file does this consistently.
- Accents are mandatory, including on capitals.
- Vocabulary: servidor, red, conexión, contraseña, correo electrónico, cuenta, configuración, suscripción, actualización, dispositivo, celular, país, ubicación.
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Gender: prefer wording that avoids a gendered adjective for the user ("¿Todo listo?" rather than "¿Estás listo/a?"). No "@", "x" or "e" endings.
- Spanish runs about 20 percent longer than English, so trim articles and filler in labels.

## es-cu

Spanish (Cuba)

- Spanish for users in Cuba. Start from neutral Latin American Spanish and prefer the word a Cuban would use where the two differ. Lantern has a large Cuban user base, so this file matters as much as the main Spanish one.
- Address the user informally with "tú", matching the existing strings. Cubans use tuteo across the board; "usted" sounds distant in an app. No voseo.
- Cuban everyday vocabulary: celular (phone), datos or datos móviles (mobile data), conexión, navegar (browse), la red, recarga (top-up), computadora, correo (email). Avoid Spain-isms entirely.
- Standard spelling and grammar; the Cuban flavour is in word choice and directness, not in slang or dropped letters.
- Buttons use the infinitive, matching the existing strings: "Conectar", "Desconectar", "Cancelar", "Continuar", "Iniciar sesión". Labels are nouns: "Configuración", "Siguiente", "Listo".
- Sentence case: only the first word and proper nouns capitalised. The file has some older Title Case labels; do not imitate them.
- Inverted punctuation and accents are mandatory, including on capitals.
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Gender: prefer wording that avoids a gendered adjective for the user. No "@", "x" or "e" endings.

## fr

French (France)

- Standard French as used in apps in France. Address the user with "vous" throughout; the existing file has no "tu".
- Buttons use the infinitive, matching the existing strings: "Connecter", "Déconnecter", "Annuler", "Continuer", "Se connecter", "Supprimer le compte". Labels are nouns: "Paramètres", "Suivant", "Terminé".
- Sentence case: only the first word and proper nouns capitalised.
- Typography: a plain space before ":", ";", "?", "!" as the existing strings do ("Mot de passe oublié ?"). Guillemets « » with a space inside for quotations.
- Accents are mandatory, including on capitals (À, É, È).
- Vocabulary: serveur, réseau, connexion, mot de passe, e-mail or adresse e-mail (the existing strings use e-mail; keep it), compte, paramètres, abonnement, mise à jour, appareil, téléphone, pays, emplacement.
- Avoid anglicisms where a French app term is standard (télécharger, mettre à jour, paramètres), but keep established ones (e-mail, Wi-Fi, VPN).
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Gender: prefer wording that avoids a gendered participle for the user ("Connexion établie" rather than "Vous êtes connecté(e)"). No inclusive-writing midpoints.
- French runs about 25 percent longer than English, so keep labels tight.

## fr-ca

French (Canada)

- Québec French as used in Canadian apps, following Office québécois de la langue française recommendations. Address the user with "vous" throughout; never "tu".
- Canadian French avoids anglicisms more strictly than France: courriel (not e-mail), téléverser (upload), télécharger (download), clavardage (chat), mot de passe, paramètres, abonnement, mise à jour, appareil, cellulaire, forfait (plan).
- Buttons use the infinitive: "Connecter", "Déconnecter", "Annuler", "Continuer", "Se connecter". Labels are nouns: "Paramètres", "Suivant", "Terminé".
- Sentence case: only the first word and proper nouns capitalised.
- Typography: a space before ":" only; no space before ";", "?", "!" (Québec convention, unlike France). Guillemets « » with a space inside for quotations.
- Accents are mandatory, including on capitals (À, É, È).
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Gender: prefer wording that avoids a gendered participle for the user ("Connexion établie"). No inclusive-writing midpoints.
- This file is being rebuilt from scratch; the old strings in it are from a different app and are not a style reference.

## pt_BR

Portuguese (Brazil)

- Brazilian Portuguese only. No European forms: tela (not ecrã), usuário (not utilizador), arquivo (not ficheiro), celular (not telemóvel), senha (not palavra-passe), aplicativo or app (not aplicação), conectar (not ligar).
- Address the user with "você" and third-person verb forms, matching the existing strings. Never "tu".
- Buttons use the infinitive, matching the existing strings: "Conectar", "Desconectar", "Cancelar", "Continuar", "Entrar", "Excluir conta". Labels are nouns: "Configurações", "Próximo", "Concluído".
- Sentence case: only the first word and proper nouns capitalised. The file has some older Title Case labels; do not imitate them.
- Progressive actions use the gerund: "Conectando...", "Carregando...".
- Accents and cedilla are mandatory, including on capitals (É, Ú, Ç).
- Vocabulary: servidor, rede, conexão, senha, e-mail, conta, configurações, assinatura (subscription), atualização, dispositivo, país, localização.
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Gender: prefer wording that avoids a gendered adjective for the user ("Tudo pronto" rather than "Você está pronto/a"). No "@", "x" or "e" endings.

## ru

Russian

- Standard Russian as used in apps. Address the user formally with "вы" in lowercase, matching the existing strings; the file has no "ты".
- Use "ё" wherever it belongs (ещё, учётная запись, перешёл), matching the existing strings.
- Buttons use the infinitive, matching the existing strings: "Подключиться", "Отключиться", "Продолжить", "Войти", "Удалить аккаунт". Labels are nouns: "Отмена", "Настройки", "Далее", "Готово".
- Sentence case: only the first word and proper nouns capitalised.
- Quotation marks «» and the long dash "—" with spaces around it.
- Vocabulary: сервер, сеть, подключение, пароль, электронная почта, аккаунт (the existing strings prefer it to учётная запись), настройки, подписка, обновление, устройство, страна, расположение.
- "Pro": "Lantern Pro" stays Latin. A standalone "Pro" is "Про" ("Перейти на Про"), matching the existing strings.
- Numbers and placeholders: Russian nouns decline with the count and there is no plural support, so phrase around the number: "Месяцев получено: %s" rather than "%s месяцев получено".
- Gender: avoid past-tense verbs and adjectives that force the user's gender ("Подключение установлено" rather than "Вы подключились").

## tr

Turkish

- Standard Turkish as used in apps in Turkey. Buttons use the short second-person imperative in Title Case, matching the existing strings: "Bağlan", "Bağlantıyı Kes", "Giriş Yap", "Devam Et", "Hesabı Sil", "İptal", "Bitti", "Sonraki". Sentences addressed to the user use the polite "siz" forms ("Lütfen tekrar deneyin"); the existing file does this consistently.
- Title Case for labels follows the English: "Ayarlar", "Hesabı Sil". Messages are sentence case.
- Turkish letters are mandatory: ı, İ, ş, ğ, ç, ö, ü. The capital of "i" is "İ" and the capital of "ı" is "I".
- Vocabulary: sunucu (server), ağ (network), bağlantı (connection), şifre, e-posta, hesap, ayarlar, abonelik, güncelleme, cihaz, ülke, konum.
- Placeholders and suffixes: Turkish attaches case suffixes whose form depends on the word, which is unknown for `%s`. Never write "%s'e" or "%s'den"; restructure so the placeholder stands alone ("Sunucu: %s", "%s için").
- Vowel harmony and consonant mutation must be correct in every suffix.
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Avoid padding with "lütfen" unless the English says "please".

## tk

Turkmen

- Standard Turkmen in the official Latin alphabet: Ää, Çç, Žž, Ňň, Öö, Şş, Üü, Ýý. Never Cyrillic.
- Buttons use the short imperative, matching the existing strings: "Birikdir", "Aýyr", "Ýatyr", "Dowam et", "Içeri gir", "Hasaby poz". Sentences addressed to the user use the polite "siz" forms ("Skrinşot goşuň", "habar beriň"); the existing file does this consistently.
- Sentence case: only the first word and proper nouns capitalised ("Dowam et", "Hasaby poz").
- Vocabulary: prefer Turkmen terms where established (tor for network, baglanyşyk for connection, açar sözi for password, hasap for account, sazlamalar for settings, täzelenme for update, ýurt for country) and accept common international terms where Turkmen apps use them (serwer, e-poçta, abunalyk, enjam).
- Avoid importing Russian words where a Turkmen or international term is in use.
- Placeholders and suffixes: Turkmen attaches case suffixes whose form depends on the word, which is unknown for `%s`. Never attach a suffix to a placeholder; restructure so it stands alone ("Serwer: %s", "%s üçin").
- Vowel harmony must be correct in every suffix.
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Few people will proofread Turkmen, so prefer the simplest clear sentence over elegant variation.

## ms

Malay (Malaysia)

- Bahasa Malaysia, not Indonesian. Vocabulary and spelling follow Malaysian usage: muat turun (not unduh), log masuk (not masuk), tetapan (not pengaturan), pelayan (server), akaun, e-mel, kata laluan, langganan, peranti, rangkaian, sambungan, kemas kini (update), cuba (not coba), boleh (not bisa).
- Address the user as "anda". Lowercase inside a sentence, capitalised at the start of a sentence or in a Title Case label ("Kod Rujukan Anda"), matching the existing strings.
- Buttons use the base verb, matching the existing strings: "Sambung", "Putuskan", "Batal", "Teruskan", "Log Masuk", "Padam Akaun". Labels are nouns: "Tetapan", "Seterusnya", "Selesai".
- Title Case for labels follows the English ("Log Masuk", "Padam Akaun"); messages are sentence case.
- Keep sentences direct; avoid padding with "sila" unless the English says "please".
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Placeholders stand alone as words with a space on each side; no prefixes or suffixes fused to them.

## my

Burmese

- Standard Burmese in Unicode encoding, never Zawgyi. The existing file is clean Unicode; keep it so.
- Polite register as in Myanmar apps: actions end with "ပါ" ("ချိတ်ဆက်ပါ", "ဆက်လုပ်ပါ") or the "ရန်" label form ("ပယ်ဖျက်ရန်", "ဝင်ရောက်ရန်"), both used in the existing strings. Address the user as "သင်".
- No spaces between words; a space may separate phrases for readability, as the existing strings do. Sentences end with "။" where the English has a period; the existing file does this consistently.
- Digits: Western (0-9) for most values, matching the majority of existing strings; Myanmar digits (၀-၉) appear only in a few older strings. Prefer Western.
- Technical terms: established Burmese term where one exists (ဆာဗာ server, ကွန်ရက် network, စကားဝှက် password, အကောင့် account, ဆက်တင်များ settings, အပ်ဒိတ် update, ချိတ်ဆက်မှု connection); English in Latin script where Myanmar apps keep it (VPN, Wi-Fi).
- "Pro": "Lantern Pro" and a standalone "Pro" stay in Latin script, matching the existing strings.
- Burmese expands considerably (median ratio 1.3); keep button labels to the shortest polite form and split long English sentences into two.
- Placeholders stand alone with a space on each side; particles follow after the space ("%s အတွက်").

## th

Thai

- Standard Thai in the neutral polite register used by apps. Address the user as "คุณ", matching the existing strings. No polite particles (ครับ/ค่ะ) in UI text.
- No spaces between words; a space separates sentences or clauses. No period at the end of a sentence even when the English has one; the existing file follows this. Question marks are used where the English has one ("ลืมรหัสผ่าน?"), matching the existing strings.
- Digits: Western (0-9), not Thai numerals.
- Technical terms: established transliterations or English as Thai apps use them: เซิร์ฟเวอร์ (server), เครือข่าย (network), การเชื่อมต่อ (connection), รหัสผ่าน (password), อีเมล (email), บัญชี (account), การตั้งค่า (settings), อัปเดต (update), อุปกรณ์ (device), ประเทศ (country).
- Buttons use the verb, matching the existing strings: "เชื่อมต่อ", "ยกเลิก", "ดำเนินการต่อ", "ลงชื่อเข้าใช้", "ลบบัญชี". Labels are nouns: "การตั้งค่า", "ถัดไป", "เสร็จสิ้น".
- "Pro": "Lantern Pro" and a standalone "Pro" stay in Latin script, matching the majority of existing strings.
- Avoid padding with "กรุณา" or "โปรด" unless the English says "please".
- Placeholders stand alone with a space on each side.

## vi

Vietnamese

- Standard Vietnamese with full diacritics on every word; a missing tone mark is a spelling error.
- Address the user as "bạn", matching the existing strings. No "quý khách".
- Sentence case only, matching the existing strings: "Cài đặt", "Xóa tài khoản", "Tiếp theo". Do not capitalise each word even when the English does.
- Buttons use the verb, matching the existing strings: "Kết nối", "Ngắt kết nối", "Hủy", "Tiếp tục", "Đăng nhập", "Xóa tài khoản". Labels are nouns: "Cài đặt", "Xong".
- Vocabulary: máy chủ (server), mạng (network), kết nối (connection), mật khẩu (password), email (kept, as Vietnamese apps do), tài khoản (account), cài đặt (settings), gói đăng ký (subscription), cập nhật (update), thiết bị (device), quốc gia (country), vị trí (location).
- Prefer everyday words over Sino-Vietnamese formal ones when both exist.
- "Pro": "Lantern Pro" and a standalone "Pro" stay as written.
- Placeholders stand alone with a space on each side.
