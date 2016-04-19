/*global $, chrome*/
/*eslint no-console: "allow"*/

function permalink (str, locale, receiver) {
 $.ajax({
    dataType: "json",
    url: "/permalink",
    data: {"value": str, "locale" : locale},
    success:  function (data) {
       console.log(data);
      $(receiver).val(data.permalink ? data.permalink : "");
    }
  });
}


$(".permalink-trigger").on("change keyup paste click", debounce(function() {
  var t = $(this), receiver = t.attr("data-permalink-receiver");
  permalink(t.val(), receiver.substr(receiver.length - 2), receiver);
}));


$( "#categories-list" ).select2({
    theme: "bootstrap",
    templateSelection: function(data, container){
       //console.log(data, container);
       return data.text;
    },
    templateResult: function(result, container){
       //console.log(result, container);
       $(container).addClass("level-" + $(result.element).attr("data-level"));
       return result.text;
    }
});
$( "#categories-list2" ).select2({
    theme: "bootstrap",
    templateSelection: function(data, container){
       //console.log(data, container);
       return data.text;
    },
    templateResult: function(result, container){
       //console.log(result, container);
       $(container).addClass("level-" + $(result.element).attr("data-level"));
       return result.text;
    }
});
