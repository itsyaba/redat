"""More free Edge-TTS data: many everyday Amharic sentences (negatives) and extra "ረዳት" takes at new
prosodies (positives). Nothing here overlaps evaltest.py. Usage: .venv/bin/python -I gen_more.py
"""
import subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
SENTENCES = """ሰላም እንዴት አደርክ?
ዛሬ ስራ በጣም ብዙ ነው።
ሻይ ወይስ ቡና ትፈልጋለህ?
መኪናው ነዳጅ ያስፈልገዋል።
ስልኩ ባትሪ አልቆበታል።
ነገ ጠዋት በሶስት ሰዓት እንገናኝ።
ይህንን ፋይል አስቀምጠው።
ኢሜይሉን አንብበኸዋል?
በጣም ደክሞኛል ትንሽ ልተኛ።
ልጁ ትምህርቱን በደንብ እያጠና ነው።
አባቴ ዛሬ ማታ ይደውላል።
እናቴ እንጀራ እየጋገረች ነው።
ዋጋው በጣም ውድ ነው።
ታክሲ ጥራልኝ እባክህ።
መንገዱ ተዘግቷል በሌላ በኩል እንሂድ።
ፊልሙ በጣም አስደሳች ነበር።
ሙዚቃውን ጨምረው።
መብራቱ ጠፍቷል።
ኢንተርኔቱ በጣም ቀርፋፋ ነው።
ኮዱን ጽፌ ጨርሻለሁ።
ስብሰባው ተሰርዟል።
ዶክተሩ መድሃኒት ሰጠኝ።
ቤቱን አጽድተናል።
እንግዶቹ መጥተዋል።
ምግቡ ቀዝቅዟል።
ውሃ አምጣልኝ።
ዛሬ ቅዳሜ ነው።
ገንዘብ ከባንክ ማውጣት አለብኝ።
የልደት ቀን ስጦታ ገዛሁለት።
በረራው ዘግይቷል።
ፕሮግራሙ ስህተት አለበት።
ጓደኛዬ ከአሜሪካ መጣ።
ዳዊት ዛሬ አልመጣም።
ራሄል ስልክ አታነሳም።
ሰዓቴ ቆሟል።
ረጅም ቀን ነበር።
እረፍት ያስፈልገኛል።
ደረጃውን ውጣ።
ረቡዕ ስብሰባ አለን።
ረዳቱ ዛሬ ታሟል።
ሬስቶራንቱ ሞልቷል።
ራት ምን እንብላ?
ዳቦ እና ወተት ግዛ።
የትራፊክ መብራቱ ቀይ ነው።
ልብሱን አጥበዋለሁ።
አትክልቱን ውሃ አጠጣው።
ድመቷ ወተት ትፈልጋለች።
ውሻው እየጮኸ ነው።
ብርዱ በጣም ከባድ ነው።
ፀሐይዋ ወጥታለች።
ዛሬ ሞቃት ነው።
ክረምቱ ደርሷል።
ቴሌቪዥኑን አጥፋው።
መስኮቱን ክፈተው።
በሩን ዝጋው።
ትምህርት ቤቱ ሩቅ ነው።
መጽሐፉን አንብቤ ጨረስኩ።
ጋዜጣው የት አለ?
ልጆቹ እየተጫወቱ ነው።
ጨዋታው ተጠናቀቀ።
ቡድናችን አሸነፈ።
ተራራውን ወጣን።
ባህር ዳር ውብ ከተማ ናት።
ጎንደር ታሪካዊ ከተማ ናት።
ሀዋሳ ሐይቅ አላት።
መርካቶ በጣም ይጨናነቃል።
ቦሌ መንገድ ላይ ነኝ።
ፒያሳ እንገናኝ።
ሳምንቱ በፍጥነት አለፈ።
ወሩ መጨረሻ ላይ ደመወዝ ይከፈላል።
ቤት ኪራይ መክፈል አለብኝ።
የቤት ስራዬን ረሳሁት።
ሰነዱን ፕሪንት አድርግልኝ።
ፓስዎርዱን ረሳሁት።
ኮምፒውተሩን እንደገና አስጀምረው።
አፕሊኬሽኑ ተዘጋ።
ስክሪኑ ጠቆረ።
ድምፁን ቀንሰው።
ቪዲዮውን አቁመው።
ቀጣዩን ዘፈን አጫውት።
ዛሬ ምን ቀን ነው?
አየሩ እንዴት ነው?
ስንት ሰዓት ሆነ?
አርፍጃለሁ ይቅርታ።
እንኳን ደስ አለህ።
አመሰግናለሁ በጣም።
ምንም ችግር የለም።
እሺ ገባኝ።
አይ አልፈልግም።
ቆይ ትንሽ።
ና ወደዚህ።
የት ነህ አሁን?
መቼ ትመጣለህ?
ለምን ዘገየህ?
ማን ደወለ?
ምን አልክ?
በጣም ጥሩ ሀሳብ ነው።
እስኪ እናስብበት።
ነገ እንነጋገራለን።
ደህና እደር።
ሬዲዮ ጣቢያውን ቀይረው።
ረድኤት ዛሬ ትመጣለች።
ራዕይ ያለው መሪ ነው።
ረዥም ጉዞ ነበር።
ዕዳዬን ከፈልኩ።
ወዳጄ ደህና ነህ?
ሬድዋን ስልክ ደወለ።
ድሮ ድሮ እዚህ ቤት ነበር።
ዳታውን ሰብስብ።
ፕሮጀክቱን ዴፕሎይ አድርገው።
ተርሚናሉን ክፈት።
ብራውዘሩን ዝጋው።
ቻናሉን ቀይር።
ትራኩን ድገመው።""".splitlines()
VOICES = ["am-ET-MekdesNeural", "am-ET-AmehaNeural"]
PROSODY = [("+0%", "+0Hz"), ("-15%", "-6Hz"), ("+15%", "+10Hz")]
POS_TEXT = ["ረዳት", "ረዳት።", "ሄይ ረዳት", "ረዳት፣", "እስኪ ረዳት", "ረዳት!"]
POS_PROSODY = [("-35%", "+0Hz"), ("+30%", "+0Hz"), ("+0%", "-20Hz"), ("+0%", "+20Hz"), ("-20%", "+10Hz"), ("+20%", "-10Hz")]


def edge(text, voice, rate, pitch, dst: Path):
    if dst.exists():
        return
    tmp = dst.with_suffix(".tmp.mp3")
    r = subprocess.run(["uvx", "edge-tts", "--voice", voice, f"--rate={rate}", f"--pitch={pitch}", "--text", text,
                        "--write-media", str(tmp)], capture_output=True, text=True)
    if r.returncode or not tmp.exists():
        return print(f"  ! {voice} {text}: {r.stderr[-150:]}", file=sys.stderr)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(tmp), "-ac", "1", "-ar", "16000", str(dst)], check=True)
    tmp.unlink()


jobs = []
for v in VOICES:
    for i, s in enumerate(SENTENCES):
        rate, pitch = PROSODY[i % len(PROSODY)]
        jobs.append((s, v, rate, pitch, DATA / "neg" / f"edgem-{v}-s{i}.wav"))
    for p, (rate, pitch) in enumerate(POS_PROSODY):
        for j, t in enumerate(POS_TEXT):
            jobs.append((t, v, rate, pitch, DATA / "pos" / f"edgem-{v}-{p}-{j}.wav"))
todo = [j for j in jobs if not j[-1].exists()]
print(f"{len(jobs)} clips, {len(todo)} to make")
with ThreadPoolExecutor(8) as ex:
    list(ex.map(lambda j: edge(*j), todo))
print("pos", len(list((DATA / "pos").glob("*.wav"))), "neg", len(list((DATA / "neg").glob("*.wav"))))
