SpotifyRemoteView = require './spotify-remote-view'
{CompositeDisposable} = require 'atom'
{exec} = require 'child_process'

module.exports = SpotifyRemote =
  spotifyRemoteView: null
  modalPanel: null
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
    @spotifyRemoteView = new SpotifyRemoteView(state.spotifyRemoteViewState)
    #@modalPanel = atom.workspace.addModalPanel(item: @spotifyRemoteView.getElement(), visible: false)
    @notification = atom.notifications

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'spotify-remote:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'spotify-remote:next': => @next()
    @subscriptions.add atom.commands.add 'atom-workspace', 'spotify-remote:previous': => @previous()

    #setInterval(this.buildData.bind(this), 2000)

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @spotifyRemoteView.destroy()

  serialize: ->
    spotifyRemoteViewState: @spotifyRemoteView.serialize()

  toggle: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 PlaybackStatus', (e, sout, serr) =>
      if sout.trim() is 'Playing'
        exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 Pause'
      else
        exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 PlayPause'
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      this.buildData =>
        @notification.addSuccess this.nowPlaying.toString()

  stop: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 PlaybackStatus', (e, sout, serr) =>
      if sout.trim() is 'Playing'
        exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 Pause'
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      #this.buildData()
      #@notification.addSuccess this.nowPlaying.toString()

  next: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 Next', (e, sout) =>
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      this.buildData =>
        @notification.addSuccess this.nowPlaying.toString()

  previous: ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 Previous', (e, sout) =>
      #@spotifyRemoteView.setInfo this.nowPlaying.toString()
      this.buildData =>
        @notification.addSuccess this.nowPlaying.toString()

  buildData: (cb) ->
    exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 Metadata', (e, musicData) =>
      exec 'qdbus org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 PlaybackStatus', (e, playStatus) =>
        this.rawSpotifyData = musicData.trim()
        this.nowPlaying.playing = if playStatus.trim() is 'Playing' then true else false

        this.nowPlaying.title = /xesam:title: (.+)/m.exec(this.rawSpotifyData)[1]
        this.nowPlaying.artist = /xesam:artist: (.+)/m.exec(this.rawSpotifyData)[1]
        this.nowPlaying.album = /xesam:album: (.+)/m.exec(this.rawSpotifyData)[1]
        cb()
