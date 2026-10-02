import edge_tts
from pydub import AudioSegment
import os


FFMPEG_PATH = r"C:\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe"
FFPROBE_PATH = r"C:\ffmpeg-9.0.2-essentials_build\bin\ffprobe.exe"

AudioSegment.converter = FFMPEG_PATH
AudioSegment.ffprobe = FFPROBE_PATH


VOICES = {
    "en": "en-US-AriaNeural",
    "hi": "hi-IN-SwaraNeural",
    "gu": "gu-IN-DhwaniNeural",
}


async def generate_speech(
    text: str,
    output_file: str,
    language: str = "en"
):
    voice = VOICES.get(language)

    if not voice:
        raise ValueError(
            f"Unsupported language: {language}"
        )

    temp_mp3 = output_file.replace(".wav", ".mp3")

    communicate = edge_tts.Communicate(
        text,
        voice
    )

    await communicate.save(temp_mp3)

    audio = AudioSegment.from_mp3(temp_mp3)

    audio.export(
        output_file,
        format="wav"
    )
    
    os.remove(temp_mp3)

    return output_file