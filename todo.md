# TODO List for KAG Gather Bot

## Current TODO:

- Finish mysql data storage conversion
    - Fix unit tests to use testing DB so that they can run
    - Test, test, test!
- Finish bot 2.0, which is bot that controls match logic, adds WARMUP mode, removes need to !end, etc
    - Make tests to ensure multiple threads can be used to manage multiple games without locking mysql connections
    - Ensure if a rcon listener thread fails the bot can continue on as normal (fail supervision)
- Fix issue where K/D stats arent always being collected (may be only with kag_user != authname users)
- Fix issue where you can !rsub in-game other team's players

## Future Additions/TODO:

- Figure out a better way to handle AFK rather than polling queue members every 2 minutes; was lagging bot signficantly
    - Consider everytime an !add/!rem is done doing afk polling
- Add !start support for server-specific matches
- Add !report decay so that they expire after X days
- REST server for stats support (use Sinatra)
    - Make easily accessible via API
