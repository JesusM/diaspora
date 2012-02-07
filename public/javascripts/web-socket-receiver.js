var WSR = WebSocketReceiver = {
  initialize: function(url) {
    WSR.socket = new WebSocket(url);

    WSR.socket.onmessage = WSR.onMessage;
    WSR.socket.onopen = function() {
      WSR.socket.send(location.pathname);
    };
  },

  onMessage: function(evt) {
    var message = $.parseJSON(evt.data);

    if(message["class"].match(/^notifications/)) {
      Diaspora.page.header.notifications.showNotification(message);
    }
    else {
      switch(message["class"]) {
        case "retractions":
          ContentUpdater.removePostFromStream(message.post_id);
          break;
        case "comments":
          ContentUpdater.addCommentToPost(message.post_guid, message.comment_guid, message.html);
          break;
        case "likes":
          ContentUpdater.addLikesToPost(message.post_guid, message.html);
          break;
        case 'chat_messages':
          var convo = $('#chat_dropdown .incoming .conversation[data-person_id="' + message.person_id + '"]');
          if( convo.length ) {
            addChatMessageToConversation( message, convo );
          } else {
            $.get(
              '/chat_messages_new_conversation.json',
              { person_id: message.person_id },
              function(response) {
                var partner = $(response.partner);
                convo = $(response.conversation);
                addChatMessageToConversation( message, convo );

                if( $('.partner.active').length ) {
                  partner.removeClass('active');
                  convo.removeClass('active');
                }

                $('.partners').append( partner );
                $('.conversations').append( convo );
              }
            );
          }
          break;
        default:
          if(WSR.onPageForAspects(message.aspect_ids)) {
            ContentUpdater.addPostToStream(message.html);
          }
          break;
      }
    }
  },

  onPageForAspects: function(aspectIds) {
    var streamIds = $("#main_stream").attr("data-guids"),
        found = false;

    $.each(aspectIds, function(index, value) {
      if(WebSocketReceiver.onStreamForAspect(value, streamIds)) {
        found = true;
        return false;
      }
    });

    return found;
  },

  onStreamForAspect: function(aspectId, streamIds) {
    return (streamIds.search(aspectId) != -1);
  }
};
