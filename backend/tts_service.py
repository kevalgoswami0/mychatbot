import edge_tts


async def generate_speech(text: str, output_file: str):
    voice = "en-US-AriaNeural"

    communicate = edge_tts.Communicate(
        text,
        voice
    )

    await communicate.save(output_file)