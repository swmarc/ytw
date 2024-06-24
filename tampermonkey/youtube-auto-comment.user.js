// ==UserScript==
// @name         YouTube Auto Comment After Watch Time
// @namespace    http://tampermonkey.net/
// @version      2.0.0
// @description  Automatically comments a YouTube video after watching a specified percentage
// @author       swmarc
// @downloadURL  https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-comment.user.js
// @updateURL    https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-comment.user.js
// @match        https://www.youtube.com/watch*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_registerMenuCommand
// @run-at       document-idle
// ==/UserScript==

(() => {
    'use strict';

    const DEFAULT_LANGUAGE = 'de_DE';
    const DEFAULT_WATCH_PERCENTAGE = 91;

    let SELECTED_LANGUAGE = GM_getValue('language', DEFAULT_LANGUAGE);
    let WATCH_PERCENTAGE = GM_getValue('watchPercentage', DEFAULT_WATCH_PERCENTAGE);

    const COMMENT_TEXTS = {
        de_DE: [
            "Gutes Video!",
            "Sehr informativ, danke!",
            "Tolles Video, weiter so!",
            "Sehr hilfreich, Danke Dir!",
            "Großartige Arbeit!",
            "Sehr lehrreich!",
            "Super informativ!"
        ],
        en_EN: [
            "Great video!",
            "Very informative, thank you!",
            "Awesome video, keep it up!",
            "Very helpful, thanks a lot!",
            "Great job!",
            "Very educational!",
            "Super informative!"
        ],
        es_ES: [
            "¡Buen video!",
            "Muy informativo, gracias!",
            "¡Gran video, sigue así!",
            "Muy útil, ¡muchas gracias!",
            "¡Gran trabajo!",
            "Muy educativo!",
            "¡Súper informativo!"
        ],
        fr_FR: [
            "Super vidéo!",
            "Très informatif, merci!",
            "Vidéo géniale, continue comme ça!",
            "Très utile, merci beaucoup!",
            "Excellent travail!",
            "Très instructif!",
            "Super informatif!"
        ],
        pt_PT: [
            "Bom vídeo!",
            "Muito informativo, obrigado/obrigada!",
            "Ótimo vídeo, continue assim!",
            "Muito útil, obrigado/obrigada!",
            "Ótimo trabalho!",
            "Muito educativo!",
            "Super informativo!"
        ]
    };

    let WATCH_THRESHOLD_REACHED = 0;

    const logDebug = message => console.debug(`[YtAutoCommentScript] ${message}`);

    const getRandomComment = () => {
        const comments = COMMENT_TEXTS[SELECTED_LANGUAGE] || COMMENT_TEXTS["en_EN"];
        return comments[Math.floor(Math.random() * comments.length)];
    };

    const enableCommentsSection = () => {
        const commentsElement = document.querySelector('#comments');
        if (commentsElement) {
            commentsElement.scrollIntoView();
            const intervalId = setInterval(() => {
                const clickEvent = new MouseEvent('click', { view: window, bubbles: true, cancelable: true });
                const commentsEnabler = document.querySelector("#placeholder-area");
                commentsEnabler.dispatchEvent(clickEvent);
                clearInterval(intervalId);

                logDebug("Clicked comments enabler.");
            }, 3000);
        } else {
            logDebug("Comments enabler not found!");
        }
    };

    const typeComment = commentBox => {
        const comment = getRandomComment();
        commentBox.innerText = comment;
        ['input', 'focus'].forEach(eventType => commentBox.dispatchEvent(new Event(eventType, { bubbles: true })));
        ['keydown', 'keyup'].forEach(eventType => commentBox.dispatchEvent(new KeyboardEvent(eventType, { 'key': 'a' })));
        logDebug(`Typed comment: ${comment}`);
    };

    const clickSubmitButton = () => {
        const submitButton = document.querySelector("#submit-button button");
        if (submitButton) {
            const intervalId = setInterval(() => {
                submitButton.click();
                logDebug("Clicked submit button.");
                clearInterval(intervalId);
            }, 3000);
        } else {
            logDebug("Submit button not found!");
        }
    };

    const waitForCommentBox = () => {
        const intervalId = setInterval(() => {
            const commentBox = document.querySelector("#contenteditable-root[contenteditable='true']");
            if (commentBox) {
                clearInterval(intervalId);
                typeComment(commentBox);
                clickSubmitButton();
            } else {
                logDebug("Comment box not found yet, waiting...");
            }
        }, 1000);
    };

    const postComment = () => {
        logDebug("Attempting to post comment...");
        enableCommentsSection();
        waitForCommentBox();
    };

    const monitorWatchTime = () => {
        const videoElement = document.querySelector('video');
        if (!videoElement) {
            logDebug('Video element not found.');
            return;
        }

        videoElement.addEventListener('timeupdate', () => {
            const watchedTime = videoElement.currentTime;
            const totalTime = videoElement.duration;

            if (totalTime > 0 && WATCH_THRESHOLD_REACHED == 0) {
                const watchedPercentage = 100 * watchedTime / totalTime;
                logDebug(`Watched percentage: ${(watchedPercentage).toFixed(2)}%`);

                if (watchedPercentage >= WATCH_PERCENTAGE) {
                    WATCH_THRESHOLD_REACHED = 1;
                    postComment();
                }
            }
        });
    };

    const openSettingsDialog = () => {
        const settingsDialog = document.createElement('div');
        settingsDialog.id = 'ytAutoCommentSettingsDialog';
        settingsDialog.style.position = 'fixed';
        settingsDialog.style.top = '50%';
        settingsDialog.style.left = '50%';
        settingsDialog.style.transform = 'translate(-50%, -50%)';
        settingsDialog.style.backgroundColor = 'white';
        settingsDialog.style.border = '1px solid #ccc';
        settingsDialog.style.padding = '20px';
        settingsDialog.style.zIndex = '9999';
        settingsDialog.style.borderRadius = '10px';
        settingsDialog.innerHTML = `
            <h2>YouTube Auto Comment Settings</h2>
            <label for="ytAutoCommentLanguage">Language:</label>
            <select id="ytAutoCommentLanguage">
                <option value="en_EN">English</option>
                <option value="fr_FR">French</option>
                <option value="de_DE">German</option>
                <option value="pt_PT">Portuguese</option>
                <option value="es_ES">Spanish</option>
            </select>
            <br><br>
            <label for="ytAutoCommentWatchPercentage">Watch Percentage:</label>
            <input type="number" id="ytAutoCommentWatchPercentage" min="0" max="100" value="${WATCH_PERCENTAGE}">
            <br><br>
            <button id="ytAutoCommentSaveSettings">Save</button>
            <button id="ytAutoCommentCloseSettings">Close</button>
        `;

        document.body.appendChild(settingsDialog);

        document.getElementById('ytAutoCommentLanguage').value = SELECTED_LANGUAGE;
        document.getElementById('ytAutoCommentWatchPercentage').value = WATCH_PERCENTAGE;

        document.getElementById('ytAutoCommentSaveSettings').addEventListener('click', saveSettings);
        document.getElementById('ytAutoCommentCloseSettings').addEventListener('click', closeSettingsDialog);
    };

    const saveSettings = () => {
        const language = document.getElementById('ytAutoCommentLanguage').value;
        const watchPercentage = parseInt(document.getElementById('ytAutoCommentWatchPercentage').value, 10);
    
        GM_setValue('language', language);
        GM_setValue('watchPercentage', watchPercentage);
    
        SELECTED_LANGUAGE = language;
        WATCH_PERCENTAGE = watchPercentage;
    
        alert('Settings saved and applied!');
    
        closeSettingsDialog();
    };

    const closeSettingsDialog = () => {
        const settingsDialog = document.getElementById('ytAutoCommentSettingsDialog');
        if (settingsDialog) {
            settingsDialog.remove();
        }
    };

    // Add a menu command to open the settings dialog
    GM_registerMenuCommand('YouTube Auto Comment Settings', openSettingsDialog);

    setTimeout(monitorWatchTime, 3000);
})();