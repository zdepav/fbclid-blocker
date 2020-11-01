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

window.addEventListener("load", () => {
    function cleanup(uri: string) {
        if (!uri) {
            return uri
        }
        let match = uri.match(
            /^(?:https?:\/\/)?lm?\.facebook\.com\/l\.php\?(?:(?:[^u=]+|u[^=]+)=[^&]+&)*u=([^&]+)(?:&|$)/
        )
        return (match ? decodeURIComponent(match[1]) : uri)
            .replace(/([?&])fbclid=[0-9a-zA-Z_-]{40,}(?:&|$)/, "$1")
            .replace(/[?&]$/, "")
    }

    const anchorCopiedAttributes = ["class", "rel", "role", "tabindex", "target"]

    function fix(a: HTMLAnchorElement) {
        let link = a.getAttribute("href")
        if (!link || link.length === 0 || link[0] === '#' || link.indexOf("www.facebook") >= 0) {
            return
        }
        const newA = document.createElement("a")
        a.parentNode.insertBefore(newA, a.nextSibling)
        const elements: Array<Node> = []
        for (let i = 0; i < a.childNodes.length; ++i) {
            elements.push(a.childNodes[i])
        }
        for (let i = 0; i < elements.length; ++i) {
            newA.appendChild(elements[i])
        }
        for (const attr of anchorCopiedAttributes) {
            newA.setAttribute(attr, a.getAttribute(attr))
        }
        newA.setAttribute("href", cleanup(link))
        if (a.hasAttribute("data-lynx-uri")) {
            newA.setAttribute(
                "data-lynx-uri",
                cleanup(a.getAttribute("data-lynx-uri"))
            )
        }
        a.remove()
    }

    for (let i = 0; i < document.links.length; ++i) {
        if (document.links[i].nodeName === "a") {
            fix(<HTMLAnchorElement>document.links[i])
        }
    }

    new MutationObserver((mutations, observer) => {
        try {
            for (const mutation of mutations) {
                mutation.addedNodes.forEach(node => {
                    if (node.nodeType !== Node.ELEMENT_NODE) {
                        return
                    }
                    (<Element>node)
                        .querySelectorAll("a")
                        .forEach(a => fix(<HTMLAnchorElement>a))
                })
            }
        } catch (e) {
            console.error("FbclidBlocker error:")
            console.error(e)
            observer.disconnect()
        }
    }).observe(document.querySelector("div[data-pagelet=root]"), {
        subtree: true,
        childList: true,
        attributes: false,
        characterData: false
    })
    console.log("FbclidBlocker initialized")
})
