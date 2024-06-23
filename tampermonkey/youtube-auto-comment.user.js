// ==UserScript==
// @name         YouTube Auto Comment After Watch Time
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Automatically comments a YouTube video after watching a specified percentage
// @author       swmarc
// @match        https://www.youtube.com/watch*
// @grant        none
// ==/UserScript==

(() => {
    'use strict';

    const WATCH_PERCENTAGE = 91;
    const COMMENT_TEXTS = [
        "Gutes Video!",
        "Sehr informativ, danke!",
        "Tolles Video, weiter so!",
        "Sehr hilfreich, Danke Dir!",
        "Großartige Arbeit!",
        "Sehr lehrreich!",
        "Super informativ!"
    ];

    let WATCH_THRESHOLD_REACHED = 0;

    const logDebug = message => console.debug(`[YtAutoCommentScript] ${message}`);

    const getRandomComment = () => COMMENT_TEXTS[Math.floor(Math.random() * COMMENT_TEXTS.length)];

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

    setTimeout(monitorWatchTime, 3000);
})();