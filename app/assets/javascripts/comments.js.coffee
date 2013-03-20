# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

change_score = ($comment, shift) ->
  current = parseInt($comment.find('.score').text())
  $comment.find('.score').text(current + shift)

$ ->
  $('.upvote').click ->
    $button = $(this)
    $comment = $button.closest('.comment')
    cid = $comment.attr('data-id')

    if $button.hasClass('active')
      # Undo upvote
      $.post "/comments/#{cid}/unvote", ->
        $button.removeClass('active')
        change_score($comment, -1)
    else
      # Either new upvote or switch from downvote
      $.post "/comments/#{cid}/upvote", ->
        $button.addClass('active')
        if $comment.find('.downvote').hasClass('active')
          $comment.find('.downvote').removeClass('active')
          change_score($comment, +2)
        else
          change_score($comment, +1)

  $('.downvote').click ->
    $button = $(this)
    $comment = $button.closest('.comment')
    cid = $comment.attr('data-id')

    if $button.hasClass('active')
      # Undo downvote
      $.post "/comments/#{cid}/unvote", ->
        $button.removeClass('active')
        change_score($comment, +1)
    else
      # Either new downvote or switch from upvote
      $.post "/comments/#{cid}/downvote", ->
        $button.addClass('active')
        if $comment.find('.upvote').hasClass('active')
          $comment.find('.upvote').removeClass('active')
          change_score($comment, -2)
        else
          change_score($comment, -1)

  $('.actions .edit').click ->
    $comment = $(this).closest('.comment')
    content = $comment.attr('data-markup')
    $comment.find('.body').html("<textarea cols=40/><button class='save'>Save</button>")
    $textarea = $comment.find('textarea').val(content)

    $comment.find('.save').click ->
      content = $textarea.val()
      $.post "/comments/#{$comment.attr('data-id')}/edit", { content: content }, ->
        $comment.find('.body').text(content)
        MathJax.Hub.Typeset($comment.get())
