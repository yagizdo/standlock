# Simplified Chinese: humour and challenge strings

This document exists so that a native Simplified Chinese speaker can review the
jokes without reading the diff. The maintainer does not speak Chinese and cannot
tell a line that lands from one that reads like a translation. The author of
issue #47 offered to correct the machine translation, and this page is what makes
that review cheap: every adapted line is here with its English source and the
reason it was written the way it was.

The document is in English so the maintainer can follow the review. The Chinese is
quoted verbatim from `StandLock/Localizable.xcstrings`.

The rest of the catalog (menus, settings, permission prompts, exercise
instructions) is a straight translation and is not listed here. Only the strings
where the joke had to be rebuilt are.

## How to give feedback

Reply with the English key and a replacement line. Two groups have hard technical
limits, so please read those sections' warnings before rewriting anything in them.

## Terminology already fixed by the rest of the catalog

| English | Chinese | Note |
|---|---|---|
| Gentle | 宽松 | Matches 宽松模式 / 降为宽松模式 already shipped. |
| Firm | 严格 | Matches 严格模式每日跳过上限 already shipped. |
| Strict | 强制 | Matches the three 强制模式需要… permission strings. |
| break | 休息 | |
| skip | 跳过 | |
| ✕ | ✕ | A glyph, not a word. Carried over unchanged so the catalog has no untranslated key. |

The three discipline level names are picker labels, so they are the bare adjective
without 模式.

| English | Chinese | Reasoning |
|---|---|---|
| Full-screen overlay with immediate skip button | 全屏遮罩，带可立即点击的跳过按钮 | Plain description, no joke. |
| Overlay with delayed skip and phrase-to-escape | 遮罩延迟跳过，需输入句子才能退出 | Plain description, no joke. |
| Full input blocking with emergency escape combo | 完全屏蔽输入，仅紧急组合键可退出 | 组合键 matches the permission strings' 退出组合键. |

## Typed escape phrases

> **Do not add punctuation to anything in this section, and do not shorten any
> line below seven characters.** These are the sentences the user has to retype to
> escape a break, compared character for character against what they typed.
> A `。` or `，` that their IME renders half-width, or drops, locks them inside the
> break with no way out. A phrase of six characters or fewer silently disables the
> bait-and-switch escalation in `PhraseDismissView`, because the code gates it on
> the phrase being longer than six characters. Spaces are out for the same reason:
> Pinyin input does not produce one, and the matcher only trims the ends.
> Every character below is reachable from standard Pinyin without hunting a
> candidate list.

### Roast challenge: the sentences the user confesses

The user types three of these, drawn at random, to buy one skip. The English is a
first-person confession that gets less dignified the longer you read it. The
Chinese keeps that: plain sentences, no slang stacking, one or two that hit harder.

| English | Chinese | Reasoning |
|---|---|---|
| I'm too lazy to stand for thirty seconds | 我懒得站起来三十秒 | Direct; 懒得 is the everyday "can't be bothered to". |
| My spine filed a complaint but I ignored it | 腰椎投诉我已读不回 | 已读不回 ("read it, didn't reply") is the current way to say you ignored someone. Sharper than a literal "I ignored it", and it keeps the complaint-desk framing. |
| I treat my legs like decorative furniture | 我把腿当装饰家具用 | Literal image, which is the joke. |
| Standing is my greatest fear | 站着是我最大的恐惧 | Direct. |
| I'd rather humiliate myself than take a break | 我宁愿丢脸也不休息 | 丢脸 (lose face) is the right register; the English "humiliate myself" is doing exactly this work. |
| My chair and I are in a committed relationship | 我和椅子已经结婚了 | "Committed relationship" translated literally (正经关系) is flat in Chinese. Marrying the chair is the equivalent escalation and reads as a joke immediately. |
| I choose early back pain over a short walk | 我宁愿腰疼也不走路 | 腰疼 not 背疼: Chinese locates desk-job pain in the lower back. |
| Exercise? I thought you said extra fries | 你说运动我听成薯条 | **The English is a soundalike pun and there is no Chinese pair that works.** Rebuilt as a plain mishearing, which keeps the structure and the fries. If a reviewer knows a real 运动/something homophone, it would be better. |
| I skipped leg day and every other day too | 我跳过练腿日和其他日 | 练腿日 is the gym term Chinese lifters use. |
| My doctor would be so disappointed right now | 我的医生现在会很失望 | Direct. |
| I'm allergic to standing up | 我对站起来严重过敏 | 严重 added: "severely allergic" is funnier than plain 过敏 and buys the character count the escalation guard needs. |
| My posture is a cry for help | 我的坐姿是求救信号 | 坐姿 not 姿势: the complaint is specifically about how they sit. |
| I consider sitting a competitive sport | 久坐是我的竞技项目 | 久坐 is the health-warning word for prolonged sitting, so calling it a competitive event is the joke. |
| My legs forgot their purpose | 我的腿已经忘了怎么用 | "Forgot how to be used" is more natural in Chinese than "forgot their purpose". |
| I treat health advice as gentle suggestions | 养生建议我一律当参考 | 养生 rather than 健康: it is the word Chinese internet culture actually mocks itself with, and 当参考 ("treat as reference material") is office-speak for ignoring something. |

### The other typed phrases

| English | Chinese | Reasoning |
|---|---|---|
| My legs are decorative | 我的腿只是装饰品 | Gentle mode's last tier. Kept shorter and blunter than the roast-pool line about decorative furniture, matching the English pair. |
| I choose to skip this break | 我选择跳过这次休息 | The default Firm escape phrase. Deliberately flat; the English is flat too. Feeds the confirmation string below. |
| %@ I really mean it | %@我是认真的 | From the earlier translation pass, rechecked. No space before 我: the matcher would demand the user type one. Resolves to 我选择跳过这次休息我是认真的. |
| Are you sure about that? | 你真的确定要跳过吗 | **Changed.** The earlier pass had 你确定吗 at four characters, which is below the escalation guard, so the third stage of the bait-and-switch never fired in Chinese. The longer form is also more exasperated, which suits the escalation. |
| I solemnly swear to take every single break from now until the end of time itself | 我郑重发誓从今以后绝不跳过任何休息 | From the earlier pass, kept. It is the final stage, meant to be the long one. Every character checked for Pinyin reachability. |
| I prefer sitting anyway | 反正我更喜欢坐着 | Strict mode's fallback. 反正 carries the English "anyway" sulk exactly. |

## Roast challenge: the app's side of the conversation

The three response pools are the point of this challenge. The app starts bored,
becomes incredulous, then gives up. If the Chinese tiers read at the same
intensity, the sequence stops being a joke even when each line is fine on its own.

| Pool | English | Chinese | Reasoning |
|---|---|---|---|
| Header 1 | You want to skip? Earn it. | 想跳过？先过这一关。 | "Earn it" as 挣来 is stilted; 先过这一关 ("get past me first") is what a Chinese speaker would say. |
| Header 2 | Not done yet. | 还没完呢。 | Direct. |
| Header 3 | Last one. Make it count. | 最后一句。好好写。 | 句 not 个: the unit is a sentence. |
| After 1st | I already knew that. Next. | 这我早知道了。下一句。 | Bored, dismissive. |
| After 1st | Tell me something I don't know. | 说点我不知道的。 | Direct. |
| After 1st | Boring. Type another one. | 无聊。换一句。 | 换 rather than 再来, so the third-tier line below can own 再来一句. |
| After 2nd | Still going? Wow. | 还在打？可以啊。 | 可以啊 is sarcastic "not bad". Deliberately not 行吧, which is reserved for the surrender tier. |
| After 2nd | You actually typed that? Impressive dedication to laziness. | 你还真打了？对懒这件事是真下功夫。 | 下功夫 ("put real effort in") applied to laziness is the same contradiction the English runs on. |
| After 2nd | Two down and zero shame. One more. | 两句了，脸都不红。再来一句。 | 脸都不红 ("didn't even blush") is the Chinese way to say shameless. |
| Final | Fine. You're even more hopeless than I thought. Take your skip. | 行吧。你比我想的还没救。跳过拿去吧。 | 行吧 is the concession particle, held back until this tier. 没救 = beyond saving. |
| Final | Okay okay, you win. Or lose. Depends on perspective. | 好好好，你赢了。或者输了。看你怎么算。 | 好好好 is the exhausted triple-agreement Chinese speakers use to end an argument. |
| Final | I'm out of insults. Skip granted, you absolute legend. | 我骂不动了。跳过批准，你真是个人才。 | 骂不动了 = "too worn out to keep mocking you". 人才 used straight-faced is standard internet sarcasm and is the closest thing to "you absolute legend". |

Read in order, the tiers go: bored, then unable to believe it, then beaten. The
closing clause moves from a demand (下一句 / 换一句) to a weaker demand
(再来一句) to handing the skip over (拿去吧 / 批准).

## Find-the-button challenge

Indexed by round, so these escalate too.

| Pool | English | Chinese | Reasoning |
|---|---|---|---|
| Header 1 | Find the right button to skip | 找到正确的按钮才能跳过 | Instruction, no joke yet. |
| Header 2 | Wrong again? Shocking. | 又错了？真意外。 | 真意外 said flatly is sarcasm in Chinese exactly as "shocking" is in English. |
| Header 3 | This is getting embarrassing | 这就有点尴尬了 | Direct. |
| Header 4 | Even a coin flip would work now | 现在扔硬币都比你准 | Made explicit ("a coin flip is more accurate than you"), because the English implication does not survive a literal Chinese rendering. |
| Exhausted | Better luck next time! | 下次好运！ | Direct. |
| Exhausted | Wow. All three. Wasted. | 哇。三次。全白费了。 | Three beats kept. |
| Exhausted | You're really committed to failing | 你对失败是真执着 | 执着 is admiring in normal use, which is what makes it cutting here. |
| Exhausted | It's literally 50/50 now | 现在真的是一半一半 | 一半一半 rather than 50/50, which reads as a statistic instead of a taunt. |
| Subtitle | One of these actually works... | 其中有一个真的能用…… | Full-width ellipsis, which is the Chinese convention. |
| Subtitle | Fewer buttons, still lost? | 按钮变少了，还是找不到？ | Direct. |
| Subtitle | Maybe standing up is easier than this | 也许站起来比这个容易 | Direct. |
| Subtitle | Two buttons. No excuses. | 两个按钮。没借口了。 | Direct. |

## Crate-opening challenge

| Pool | English | Chinese | Reasoning |
|---|---|---|---|
| Header 1 | So you'd rather gamble than stand up | 所以你宁可赌一把也不站起来 | 赌一把 is the colloquial "take a gamble". |
| Header 2 | Bold of you to try again | 还敢再来一次，勇气可嘉 | 勇气可嘉 ("commendable courage") is a set phrase used almost exclusively sarcastically. |
| Header 3 | Fine. Last spin. | 行。最后一次。 | Direct. |
| Lose 1 | Saw that coming | 早就猜到了 | Direct. |
| Lose 2 | Genuinely impressive | 输成这样也不容易 | The English is sarcasm about losing twice. Translated straight (真厉害) it could be read as praise, so it is made explicit: "losing this consistently is actually hard". |
| Subtitle 1 | Most of these are red. Just saying. | 这里面大多数是红的。随口一说。 | 随口一说 is the Chinese "just saying". |
| Subtitle 2 | Still feeling lucky? | 还觉得自己有手气？ | 手气 is the gambling-specific word for luck. |
| Subtitle 3 | Last chance. No pressure. | 最后一次机会。别有压力。 | Also used as the slot machine's third header; one key, one line. |
| Win | Ugh. Fine, go. | 啧。行，去吧。 | 啧 is the written form of the annoyed tongue click. |

## Slot machine

| Pool | English | Chinese | Reasoning |
|---|---|---|---|
| Header 1 | Feeling lucky? | 觉得自己手气好？ | Matches 手气 above. |
| Header 2 | Double or nothing... well, nothing or nothing | 要么翻倍要么归零……其实只有归零 | 要么…要么 is the standard "either/or"; the self-correction survives intact. No terminal stop, matching the English trail-off. |
| Subtitle 1 | Stop each reel on Skip to win | 每个轮盘都停在“跳过”上才算赢 | 跳过 in quotes because it names the symbol on the reel, which the catalog already translates as 跳过. |
| Subtitle 2 | Reels are a bit slower now. You're welcome. | 轮盘现在慢了一点。不用谢。 | 不用谢 is the sarcastic "you're welcome". |
| Subtitle 3 | One reel. One button. No excuses. | 一个轮盘。一个按钮。没借口。 | Three beats kept. |
| Loss | The house always wins | 庄家永远赢 | 庄家 is the house/dealer. The saying exists in Chinese gambling talk. |
| Loss | Two out of three ain't... well, it IS bad here. | 三中二不算差……好吧在这儿很差。 | **The English is a Meat Loaf song title ("Two Out of Three Ain't Bad") and that reference is dead in China.** Kept only the structure: assert it's not bad, then immediately concede it is. |
| Loss | Impressive. Not a single one. | 厉害。一个都没中。 | Sarcastic 厉害, then the flat fact. |
| Near miss | Soooo close. The universe has a cruel sense of humor. | 就差一点点。宇宙的幽默感真狠。 | 真狠 ("really vicious") is the natural Chinese complaint about bad luck. |
| Win | Genuinely impressive. Fine, go. | 是真有点厉害。行，去吧。 | 是真 marks this one as sincere, unlike the sarcastic 厉害 above. |
| Win | Took you two tries but okay. | 花了两次，不过也行。 | Direct. |
| Win | Jackpot. Ugh. | 中头奖了。啧。 | 中头奖 is the standard "hit the jackpot". |
| Fallback | Fine. Just type this: | 行。那就打这句： | Full-width colon. |

## Splash texts

These render rotated at small size, three at a time, so each is kept short. The
developer in-jokes keep their command, acronym or key combination in ASCII,
because a Chinese developer reads `sudo`, `LGTM` and `Ctrl+Z` untranslated and
translating them would destroy the joke.

| English | Chinese | Reasoning |
|---|---|---|
| Ctrl+Z won't fix your posture | Ctrl+Z 救不了你的坐姿 | Key combination kept. |
| Two minutes. You'll survive. | 两分钟，死不了 | 死不了 ("you won't die") is blunter than the English and more idiomatic. |
| Even CPUs need cooling breaks | CPU 都要散热 | 散热 is the standard hardware word. |
| Stretch now, debug later | 先拉伸，再调试 | 先…再… keeps the parallel structure. |
| Consecutive skip detected | 检测到连续跳过 | Deadpan system-message register, as in English. |
| Screen time: hours. Break time: refused. | 屏幕数小时，休息零次 | The English colon structure runs long in Chinese, so it became a contrast pair instead. |
| Standing: surprisingly not fatal | 站着居然不致命 | 居然 carries the "surprisingly". |
| Brief pause. Big difference. | 停一下，差很多 | Short/big contrast kept. |
| The chair isn't going anywhere | 椅子又不会跑 | 又不会 is the dismissive "it's not like it will". |
| You're still here? | 你还在这儿？ | Direct. |
| Never gonna give you up | 你已被瑞克摇 | **Rickroll.** It circulates in China as 瑞克摇. Translating the lyric would lose the reference entirely, so this states the rickroll instead: "you have been Rickrolled". Flagging it: I am fairly confident 瑞克摇 is the current term, less confident that it is recognised outside younger internet users. |
| This is fine. | 一切正常 | The burning-room dog. The meme's Chinese caption is usually 一切正常 or 这没事. Deadpan and short. Reviewer check: does the image come to mind, or does it read as a plain status line? |
| One does not simply skip breaks | 休息哪能说跳就跳 | **Boromir.** The meme's snowclone has no fixed Chinese form, so the sentence is rebuilt on 说跳就跳, a native pattern meaning "just skip it like that", which carries the same "you don't get to do that casually" sense. |
| I'm in this picture and I don't like it | 图里有我，不开心 | Chinese netizens say 这张图里有我，我不开心. Trimmed to fit the splash size. |
| Go touch some grass | 去外面摸摸草 | **Lowest-confidence line in this document.** "Touch grass" has no established Chinese equivalent; the usual advice is 出去走走 ("go outside"), which loses the mockery. The literal 摸草 is kept because the `git commit` line below depends on it, but if a reviewer says it reads as nonsense, both lines should change together. |
| git commit -m "touched grass" | git commit -m "摸过草了" | Command kept in ASCII, message translated, paired with the line above. |
| sudo stand up | sudo 站起来 | `sudo` kept; translating it kills the joke. |
| Have you tried turning yourself off and on? | 试过把自己重启吗 | 重启 (reboot) is the word Chinese support desks use, so the joke transfers cleanly. |
| It works on my spine | 在我腰上是好的 | From "it works on my machine", which Chinese developers say as 在我机器上是好的. Swapping 机器 for 腰 reproduces the original joke's mechanics exactly. |
| LGTM. Now stand up. | LGTM，站起来吧 | `LGTM` kept; Chinese code review uses it untranslated. |

## Known gaps

1. **`Exercise? I thought you said extra fries`** is a soundalike pun in English
   and is not one in Chinese. It is now a plain mishearing joke. A real homophone
   would be better if one exists.
2. **`Go touch some grass`** may not read as a reference at all. See the note
   above.
3. **`Never gonna give you up`** depends on 瑞克摇 being current in 2026.
4. **`Two out of three ain't... well, it IS bad here.`** loses its song reference
   entirely. Only the structure survives.
5. Nothing here was reviewed by a native speaker before it shipped.
