{CompositeDisposable} = require 'atom'
{exec} = require 'child_process'

module.exports = SpotifyRemote =
  subscriptions: null
  rawSpotifyData: ''
  nowPlaying: {
    playing: false
    title: ''
    artist: ''
    album: ''
    toString: ->
      "#{if this.playing then 'Playing' else 'Paused'}: #{ this.artist } - #{ this.title }  [#{ this.album }]"
  }

  activate: (state) ->
    @notification = atom.notifications
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'spotify-remote:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'spotify-remote:next': => @next()
    @subscriptions.add atom.commands.add 'atom-workspace', 'spotify-remote:previous': => @previous()

    atom.packages.onDidActivateInitialPackages =>
        @element = document.createElement 'div'
        @element.id = 'status-bar-spotify'
        @element.classList.add 'inline-block'
        @statusBar = document.querySelector('status-bar')
        @statusBar.addLeftTile(item: @element, priority: 100)
        @element.innerHTML = "Spotify Now Playing"
        this.statusElement = @element

    setInterval @tick.bind(this), 2000

    #setInterval(this.buildData.bind(this), 2000)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @spotifyRemoteView.destroy()

  toggle: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause', (e, sout, serr) =>
      if e
        @notification.addWarning 'Spotify may not be running'
      this.buildData()

  stop: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlaybackStatus', (e, sout, serr) =>
      if sout.trim() is 'Playing'
        exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause'

  next: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Next', (e, sout) =>
      if e
        @notification.addWarning 'Spotify may not be running'
      this.buildData()

  previous: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Previous', (e, sout) =>
      if e
        @notification.addWarning 'Spotify may not be running'
      this.buildData()

  buildData: () ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Metadata', (e, musicData) =>
      exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlaybackStatus', (e, playStatus) =>
        this.rawSpotifyData = musicData.trim()
        if this.rawSpotifyData
          this.nowPlaying.playing = if playStatus.trim() is 'Playing' then true else false

          title = /xesam:title: (.+)/m.exec(this.rawSpotifyData)
          artist = /xesam:artist: (.+)/m.exec(this.rawSpotifyData)
          album = /xesam:album: (.+)/m.exec(this.rawSpotifyData)

          this.nowPlaying.title = title && title[1] || ''
          this.nowPlaying.artist = artist && artist[1] || ''
          this.nowPlaying.album = album && album[1] || ''

  tick: ->
    this.buildData()
    if this.statusElement
      this.statusElement.innerHTML = this.nowPlaying.toString()
