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
        if this.rawSpotifyData != null
            "#{if this.playing then 'Playing' else 'Paused'}: #{ this.artist } - #{ this.title }  [#{ this.album}]}"
        else
            "Spotify is not running."
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
        @element.innerHTML = "Spotify is not running."
        this.statusElement = @element

    setInterval @tick.bind(this), 2000

    #setInterval(this.buildData.bind(this), 2000)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @spotifyRemoteView.destroy()

  toggle: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause', (e, sout, serr) =>
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      this.buildData =>
        @notification.addSuccess this.nowPlaying.toString()
        this.tick()

  stop: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlaybackStatus', (e, sout, serr) =>
      if sout.trim() is 'Playing'
        exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Pause'
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      #this.buildData()
      #@notification.addSuccess this.nowPlaying.toString()
      this.tick()

  next: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Next', (e, sout) =>
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      this.buildData =>
        @notification.addSuccess this.nowPlaying.toString()
        this.tick()

  previous: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Previous', (e, sout) =>
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      this.buildData =>
        @notification.addSuccess this.nowPlaying.toString()
        this.tick()

  buildData: (cb) ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.Metadata', (e, musicData) =>
        if (e == null)
            exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlaybackStatus', (e, playStatus) =>
                if (e == null)
                    this.rawSpotifyData = musicData.trim()
                    this.nowPlaying.playing = if playStatus.trim() is 'Playing' then true else false
                    this.nowPlaying.title = /xesam:title: (.+)/m.exec(this.rawSpotifyData)[1]
                    this.nowPlaying.artist = /xesam:artist: (.+)/m.exec(this.rawSpotifyData)[1]
                    this.nowPlaying.album = /xesam:album: (.+)/m.exec(this.rawSpotifyData)[1]
                    cb()
        else
            this.rawSpotifyData = null
            cb()

  tick: ->
    #@spotifyRemoteView.setInfo this.nowPlaying.toString()
    this.buildData =>
        this.statusElement.innerHTML = this.nowPlaying.toString()
