# Recognition fixtures

- `pikachu.png` and `espeon.png`: PokeAPI/sprites official artwork for species 25 and 196. Used to test the shipped Core ML model through the actual iOS preprocessing path, with no visible name required.
- `kadabra-card.jpeg`: public real card photograph `Images/5640.jpeg` from stevelohwc/pokemon_card_image_for_authenticity_classification, revision 91851c4aa6644071f7b0cf7f43ea1305f8bd1af1. Retained as a difficult visual scan fixture; no text recognition is used.

Pokémon artwork belongs to its respective owners. These fixtures are for prototype evaluation.

Images are local-only and ignored by Git. After cloning, run `python3 Tools/download_test_fixtures.py` before building the test targets.
