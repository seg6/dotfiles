package theme

const wallpaperPreviewHTML = `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{.Name}} · Overprint</title>
<style>
:root{ {{.PaletteCSS}} }
*{box-sizing:border-box}body{margin:0;background:var(--bg_alt);color:var(--fg);font:16px/1.5 "Fantasque Sans Mono",monospace}main{max-width:1440px;margin:0 auto;padding:28px}h1{font-size:28px;margin:0}p{color:var(--dim);margin:4px 0 24px}code{color:var(--accent)}.desktop{position:relative;width:1280px;height:720px;transform-origin:top left;overflow:hidden;background:var(--desk)}.desktop>img{position:absolute;width:100%;height:100%;object-fit:cover}.canvas{overflow:auto;outline:1px solid var(--edge)}.rail{position:absolute;left:14px;top:15px;bottom:15px;width:47px;background:var(--paper);border:1px solid var(--ink);box-shadow:3px 3px var(--ink);color:var(--ink);display:flex;flex-direction:column;align-items:center;gap:14px;padding:20px 6px;font-size:14px;font-weight:bold}.mark{height:24px;width:24px;position:relative;margin-bottom:12px}.mark:before,.mark:after{content:"";position:absolute;width:16px;height:16px;border:2px solid var(--ink)}.mark:after{left:8px;top:8px;background:var(--active)}.rail span{display:grid;place-items:center;width:32px;height:31px}.rail .on{background:var(--active);color:var(--paper);box-shadow:3px 3px var(--ink)}.rail time{margin-top:auto;text-align:center;font-size:12px}.windows{position:absolute;left:83px;right:24px;top:32px;bottom:36px;display:grid;grid-template-columns:minmax(0,2.2fr) minmax(0,1fr);gap:24px}.window{background:var(--bg);border:1px solid var(--accent);box-shadow:4px 4px var(--shadow);min-width:0;display:flex;flex-direction:column}.heading{height:25px;flex:none;background:var(--header);color:var(--fg);padding:5px 8px;font-size:10px;border-bottom:0}.heading span{float:right;color:var(--header_dim)}pre{font:12px/1.62 "Fantasque Sans Mono",monospace;white-space:pre-wrap;margin:0;padding:18px;flex:1;overflow:hidden}.dim{color:var(--dim)}.keyword{color:var(--magenta)}.string{color:var(--green)}.number{color:var(--red)}.function{color:var(--accent)}.mode{font-size:11px;display:flex;justify-content:space-between;padding:0 10px}.mode b{background:var(--accent);color:var(--bg);padding:0 5px}.tmux{height:43px;border-top:1px solid var(--surface_alt);margin:6px 10px 0;display:flex;align-items:flex-start;justify-content:space-between;padding-top:7px;font-size:10px}.tmux strong{color:var(--accent)}.tabs{display:flex;gap:10px;align-items:center}.tabs>span{color:var(--dim);padding:1px 3px}.tabs .active{color:var(--bg);background:var(--accent);box-shadow:7px 6px var(--ink);padding:1px 7px}.tabs i{font-weight:bold}.side{display:grid;grid-template-rows:1fr 1fr;gap:24px}.files{padding:16px 10px;font-size:11px;line-height:2.1}.files>div{padding:0 8px}.files .selected{background:var(--surface_alt)}.files small{float:right;color:var(--dim)}.palette{display:flex;gap:6px;flex-wrap:wrap;margin-top:20px}.swatch{width:90px;font-size:10px;color:var(--dim)}.swatch b{display:block;height:30px;border:1px solid var(--edge)}
</style>
<main><h1>{{.Name}}</h1><p>The Overprint layout, with colors from this wallpaper. Apply with <code>theme use {{.ID}}</code>.</p>
<div class="canvas"><div class="desktop"><img src="{{.Wallpaper}}" alt="Wallpaper used for this palette">
<aside class="rail"><div class="mark"></div><span>1</span><span class="on">2</span><span>8</span><time>19<br>42</time></aside>
<div class="windows"><section class="window"><div class="heading">dotfiles:1:editor<span>~/workspace/personal/dotfiles</span></div>
<pre><span class="dim"> 1</span> <span class="keyword">package</span> desktop

<span class="dim"> 3</span> <span class="keyword">type</span> Palette <span class="keyword">struct</span> {
<span class="dim"> 4</span>     Background <span class="keyword">string</span>
<span class="dim"> 5</span>     Foreground <span class="keyword">string</span>
<span class="dim"> 6</span>     Accent     <span class="keyword">string</span>
<span class="dim"> 7</span> }

<span class="dim"> 9</span> <span class="dim">// Same desktop. A different atmosphere.</span>
<span class="dim">10</span> <span class="keyword">func</span> <span class="function">Apply</span>(wallpaper <span class="keyword">string</span>) error {
<span class="dim">11</span>     palette := <span class="function">FromWallpaper</span>(wallpaper)
<span class="dim">12</span>     <span class="keyword">return</span> desktop.<span class="function">Recolor</span>(palette)
<span class="dim">13</span> }

<span class="dim">15</span> <span class="keyword">const</span> spacing = <span class="number">48</span>
<span class="dim">16</span> <span class="keyword">const</span> font = <span class="string">"Fantasque Sans Mono"</span></pre>
<div class="mode"><span><b>NORMAL</b> palette.go</span><span class="dim">main 11:24 UTF-8 go</span></div>
<div class="tmux"><strong>dotfiles</strong><div class="tabs"><span class="active"><i>1</i> editor</span><span><i>2</i> fish</span><span><i>8</i> git</span><span><i>9</i> files</span></div><span class="dim">19:42</span></div></section>
<div class="side"><section class="window"><div class="heading">dotfiles:2:fish</div><pre>dotfiles <span class="dim">main</span> <span class="function">▞</span> theme wallpaper image.jpg

<span class="string">Palette saved.</span>

<span class="dim">Colors change.
Spacing, typography and behavior stay.</span>

<span class="function">▞</span> █</pre></section>
<section class="window"><div class="heading">dotfiles:9:files</div><div class="files"><div>▸ dotfiles <small>4 items</small></div><div class="selected">▸ themes <small>26 items</small></div><div>▸ tools <small>1 item</small></div><div>· bootstrap <small>6.1 KiB</small></div><div>· config.yaml <small>5.4 KiB</small></div></div></section></div></div></div></div>
<div class="palette">{{range $key,$value:=.Colors}}<div class="swatch"><b style="background:{{$value}}"></b>{{$key}}<br>{{$value}}</div>{{end}}</div>
</main></html>`
