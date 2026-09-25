# My Glove80

My Glove80 config. Some layers omitted due to insignificance.

## macOS

The symbol layer sends RALT+key for ç, ¿, ¡ and the literal `` ` ~ ' " ^ ``.
Those are the AltGr symbols of the Linux `us(intl)` layout. macOS treats RALT
as Option, and its own Option symbols are different.

`make install-keylayout` copies `US-Intl-AltGr.keylayout` to
`~/Library/Keyboard Layouts`. It is
"U.S. International – PC" with the `us(intl)` AltGr layer on Option.
`scripts/gen-keylayout-altgr.swift` generates it. To use it:

1. Log out and log in again.
2. Open System Settings > Keyboard > Input Sources > Edit.
3. Add "US Intl AltGr" from the "Others" group and select it.

## Layer 0: Homerow Mod
<img width="1300" height="593" alt="image" src="https://github.com/user-attachments/assets/83695764-4153-44ee-a1cc-ed17d0e3a698" />

## Layer 2: Cursor
<img width="1299" height="588" alt="image" src="https://github.com/user-attachments/assets/5c7be20d-c092-4231-b654-d54b5956d543" />

## Layer 3: Lower
<img width="1300" height="595" alt="image" src="https://github.com/user-attachments/assets/3c773207-70f4-4e1b-a55c-2b9240a4e205" />

## Layer 17: __Symbol__
<img width="1293" height="590" alt="image" src="https://github.com/user-attachments/assets/e4adabe2-89fb-4346-80f7-b70060da6e98" />

## Layer 12: Mouse
<img width="1288" height="596" alt="image" src="https://github.com/user-attachments/assets/ec05507a-c671-4430-ab30-bd66574fabad" />
