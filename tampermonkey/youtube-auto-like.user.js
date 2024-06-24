// ==UserScript==
// @name         YouTube Auto Like After Watch Time
// @namespace    http://tampermonkey.net/
// @version      1.0.2
// @description  Automatically likes a YouTube video after watching a specified percentage
// @author       swmarc
// @downloadURL  https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-like.user.js
// @updateURL    https://github.com/swmarc/ytw/raw/main/tampermonkey/youtube-auto-like.user.js
// @match        https://www.youtube.com/watch*
// @grant        none
// ==/UserScript==

(() => {
    'use strict';

    const WATCH_PERCENTAGE = 90;
    const LIKE_BUTTON_SELECTOR = 'like-button-view-model button';

    let WATCH_THRESHOLD_REACHED = 0;

    const logDebug = message => console.debug(`[YtAutoLikeScript] ${message}`);

    const isLiked = () => {
        const likeButton = document.querySelector(LIKE_BUTTON_SELECTOR);
        return likeButton && likeButton.getAttribute('aria-pressed') === 'true';
    };

    const likeVideo = () => {
        if (!isLiked()) {
            const likeButton = document.querySelector(LIKE_BUTTON_SELECTOR);
            if (likeButton) {
                likeButton.click();
                logDebug('Video liked automatically.');
            } else {
                logDebug('Like button not found.');
            }
        } else {
            logDebug('Video already liked.');
        }
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
                    likeVideo();
                }
            }
        });
    };

    setTimeout(monitorWatchTime, 3000);
})();
