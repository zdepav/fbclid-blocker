// Browser extension that removes fbclid parameter from all links on facebook.
// Copyright (C) 2020 Zdeněk Pavlátka
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

(() => {
    let link = location.href
        .replace(/([?&])fbclid=[0-9a-zA-Z_-]{40,}(?:&|$)/, "$1")
        .replace(/[?&]$/, "");
    if (link != location.href) {
        history.replaceState(null, '', link)
    }
})()
