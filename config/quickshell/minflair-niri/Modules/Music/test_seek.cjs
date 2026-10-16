// Test the actual service functions without controlling any real player.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../../Core/Services/MprisService.qml'), 'utf8');
const block = source.slice(source.indexOf('    function seekTo('), source.indexOf('    Timer {', source.indexOf('    function seekTo(')));
const create = new Function('root', 'seekPauseTimer', 'recoveryCheckTimer', block + '\nreturn {seekTo, finishBrowserSeek};');
function fixture({browser=true, playing=true, delayed=false, canSeek=true}={}) {
    const events=[];
    const player={dbusName: browser ? 'org.mpris.MediaPlayer2.firefox.test' : 'org.mpris.MediaPlayer2.vlc',
        canSeek, positionSupported:true, lengthSupported:true, length:100, uniqueId:1, isPlaying:playing,
        pause(){events.push('pause'); if(!delayed)this.isPlaying=false;},
        play(){events.push('play');this.isPlaying=true;}};
    Object.defineProperty(player,'position',{set(value){events.push(['seek',value]);if(browser&&this.isPlaying)this.lengthSupported=false;}});
    const root={activePlayer:player,seekPlayer:null,seekTarget:0,seekTrack:-1,seekAttempts:0,
        timelineDuration:100, rememberDuration(){}};
    const methods=create(root,{restart(){events.push('timer');}},{restart(){}});
    return {player,root,methods,events};
}
{
    const f=fixture();f.methods.seekTo(40);f.methods.finishBrowserSeek();
    assert.deepEqual(f.events,['pause','timer',['seek',40],'play']);
    assert.equal(f.player.lengthSupported,true);assert.equal(f.root.seekPlayer,null);
}
{
    const f=fixture({playing:false});f.methods.seekTo(40);
    assert.deepEqual(f.events,[['seek',40]]);assert.equal(f.player.isPlaying,false);
}
{
    const f=fixture({browser:false});f.methods.seekTo(200);
    assert.deepEqual(f.events,[['seek',100]]);
}
{
    const f=fixture({delayed:true});f.methods.seekTo(40);f.methods.finishBrowserSeek();
    assert.equal(f.events.filter(e=>Array.isArray(e)).length,0);
    f.player.isPlaying=false;f.methods.finishBrowserSeek();
    assert.deepEqual(f.events.slice(-2),[['seek',40],'play']);
}
{
    const f=fixture();f.methods.seekTo(40);f.methods.seekTo(60);f.methods.finishBrowserSeek();
    assert.equal(f.events.filter(e=>e==='pause').length,1);
    assert.deepEqual(f.events.slice(-2),[['seek',60],'play']);
}
{
    const f=fixture({delayed:true});f.methods.seekTo(40);
    for(let i=0;i<20;i++)f.methods.finishBrowserSeek();
    assert.equal(f.root.seekPlayer,null);assert.equal(f.events.filter(e=>Array.isArray(e)).length,0);
}
{
    const f=fixture();f.methods.seekTo(40);f.player.uniqueId=2;f.methods.finishBrowserSeek();
    assert.equal(f.root.seekPlayer,null);assert.equal(f.events.filter(e=>Array.isArray(e)).length,0);
}
{
    const f=fixture({canSeek:false});f.methods.seekTo(40);assert.deepEqual(f.events,[]);
}
console.log('8 seek tests passed; no real playback changed.');
const timelineSource=fs.readFileSync(path.join(__dirname,'Components/TimelineState.js'),'utf8').replace(/^\.pragma library\s*/, '');
const retain=new Function(timelineSource+'\nreturn retainDuration;')();
let state=retain({key:'',seconds:0},'video-a',true,2513);
assert.equal(state.seconds,2513);
assert.equal(retain(state,'video-a',false,900),state);
assert.equal(retain(state,'video-b',false,900).seconds,0);
assert.equal(retain(state,'video-a',true,NaN),state);
assert.equal(retain(state,'video-a',true,0),state);
assert.equal(retain(state,'video-a',true,2500).seconds,2500);
assert.equal(retain(state,'',false,900).seconds,0);
console.log('7 duration-retention tests passed.');
const identity=new Function(timelineSource+'\nreturn identity;')();
assert.equal(identity('firefox','https://www.youtube.com/watch?v=abcdefghijk',1),
    identity('firefox','https://www.youtube.com/watch?v=abcdefghijk&t=123',2));
assert.notEqual(identity('firefox','https://www.youtube.com/watch?v=abcdefghijk',1),
    identity('firefox','https://www.youtube.com/watch?v=lmnopqrstuv',2));
console.log('2 track-identity tests passed.');

// Extract real QML JavaScript blocks, without launching yt-dlp or changing media.
function bodyAfter(marker, offset=0) {
    const start=source.indexOf('{',source.indexOf(marker,offset));
    let depth=1, end=start+1;
    while(depth && end<source.length) {
        if(source[end]==='{')depth++;
        if(source[end]==='}')depth--;
        end++;
    }
    return source.slice(start+1,end-1);
}
const rememberBody=bodyAfter('function rememberDuration()');
const lookupOffset=source.indexOf('id: durationLookupTimer');
const lookupBody=bodyAfter('onTriggered:',lookupOffset);
for(const needed of [false,true]) {
    let scheduled=0;
    const root={activePlayer:{lengthSupported:false,length:0},durationState:{key:'video',seconds:0},
        timelineKey:'video',timelineUrl:'https://www.youtube.com/watch?v=abcdefghijk',
        timelineNeeded:needed,timelineDuration:0,durationRequestKey:''};
    new Function('root','TimelineState','durationLookupTimer',rememberBody)(root,
        {retainDuration:retain},{restart(){scheduled++;}});
    assert.equal(scheduled,needed?1:0);
    const proc={running:false};
    new Function('root','durationLookupProc',lookupBody)(root,proc);
    assert.equal(proc.running,needed);
    if(needed)assert.equal(proc.command.at(-1),'https://www.youtube.com/watch?v=abcdefghijk');
}
console.log('4 lazy-duration scheduling tests passed; no network requests.');
