# General

The application must operate 100% offline after flashing the ESP32.

The browser will connect directly to the ESP32 over the local Wi-Fi network.
There is no Internet connection available at runtime.

Therefore:

- Do not use CDNs.
- Do not use Google Fonts.
- Do not load external JavaScript.
- Do not load external CSS.
- Do not call external APIs.
- Do not reference remotely hosted icons or images.
- All HTML, CSS, JS, SVG icons, fonts, and other assets must be stored locally
  and served by the ESP32.

Use Tailwind during development, compiled CSS on the ESP32.

The ESP32 doesn't run Tailwind.

Your development machine runs:

Tailwind
    ↓
compile
    ↓
app.min.css
    ↓
ESP32 flash

Tailwind generates CSS based on the utilities actually used by your pages and provides production minification, which can result in a small final stylesheet.

So your ESP32 only sees:

app.min.css

application must render both on phones and pc.

# App layout

First UI element is a display that looks like a 7 segment display of a generic digital scale that displays the measured weight in g or lb depending on the mode.

below weight display we should have a tare button that zeros the measurment. and mode button that switches between measurment units.

when measurment stabilizes. the value displayed in the display must freeze and flicker 3 times. it must unfreeze when a change of delta > 2 grams is detected.

below this basic digilat scale ui layout, app must display a horizontal array of clickable box objects which will be scrollable horizontally. each box object must be a 30x30 pixel icon that represent one type of user defined food and can be clicked to be selected. on top of this array of food icons we must also include food search and add buttons. search button will enable user to search and select food type by name. and add button must pop a seperate window where user can enter food name, one of the preset icons and background color. and following values per 100g: calories, proteins, and carbohydrates. user will press add button to finish adding the new food. allow duplicate food entries and only food name must be required field in add food manu. others will be optional. icon will be selected by random if left unchosen. food entries by the user must be then stored inside esp32 eeprom memory to permanently save them.

when food icon is selected by the user:
below the horizontal array of food icons should appear a list of food contents in a following layout:

Calories:.......xx g
Protein:........xx g
Fat:............xx g
Carbohydrates:..xx g

make displayed values (numbers) on the right side are  vertically alligned

when a food is selected and scale makes measurment of X grams. it should automatically calculate proportionally how much of each of the 4 types of food consistencies are in that X gram of that selected food and dispkay it below the food array element.

# Brief app layout scketch
```
0000xxx g
Tare | Mode

Search.. | add..
food1 | food2 | food3 |

Calories:.......xx g
Protein:........xx g
Fat:............xx g
Carbohydrates:..xx g
```