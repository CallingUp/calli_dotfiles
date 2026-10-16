.pragma library

function identity(bus, url, track) {
    const match = url.match(/^https:\/\/(?:www\.|music\.)?youtube\.com\/watch\?[^#]*\bv=([A-Za-z0-9_-]{11})(?:&|$)/)
        || url.match(/^https:\/\/youtu\.be\/([A-Za-z0-9_-]{11})(?:[?&#]|$)/);
    return bus + "|" + (match ? "youtube:" + match[1] : (url || String(track)));
}

function retainDuration(previous, key, supported, seconds) {
    if (!key) return { key: "", seconds: 0 };
    if (supported && Number.isFinite(seconds) && seconds > 0) {
        if (previous.key === key && previous.seconds === seconds) return previous;
        return { key: key, seconds: seconds };
    }
    return previous.key === key ? previous : { key: key, seconds: 0 };
}
