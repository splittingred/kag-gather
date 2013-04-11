# TODO List for KAG Gather Bot

## Current TODO:

- Finish mysql data storage conversion
    - Test, test, test!
- Fix issue where you can !rsub in-game other team's players

## Future Additions/TODO:

- Figure out a better way to handle AFK rather than polling queue members every 2 minutes; was lagging bot signficantly
    - Consider everytime an !add/!rem is done doing afk polling
- Add !start support for server-specific matches
- Add !report decay so that they expire after X days
- REST server for stats support (use Sinatra)
    - Make easily accessible via API
