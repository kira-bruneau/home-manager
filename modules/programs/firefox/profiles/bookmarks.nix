{ config, lib, pkgs, }:

with lib;

let
  bookmarkSubmodule = types.submodule ({ name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
        description = "Bookmark name.";
      };

      tags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Bookmark tags.";
      };

      keyword = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Bookmark search keyword.";
      };

      url = mkOption {
        type = types.str;
        description = "Bookmark url, use %s for search terms.";
      };
    };
  }) // {
    description = "bookmark submodule";
  };

  bookmarkType = types.addCheck bookmarkSubmodule (x: x ? "url");

  directoryType = types.submodule ({ name, ... }: {
    options = {
      name = mkOption {
        type = types.str;
        default = name;
        description = "Directory name.";
      };

      bookmarks = mkOption {
        type = types.listOf nodeType;
        default = [ ];
        description = "Bookmarks within directory.";
      };

      toolbar = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Make this the toolbar directory. Note, this does _not_
          mean that this directory will be added to the toolbar,
          this directory _is_ the toolbar.
        '';
      };
    };
  }) // {
    description = "directory submodule";
  };

  nodeType = types.either bookmarkType directoryType;

  bookmarksFile = bookmarks:
    let
      indent = level:
        lib.concatStringsSep "" (map (lib.const "  ") (lib.range 1 level));

      bookmarkToHTML = indentLevel: bookmark:
        ''
          ${indent indentLevel}<DT><A HREF="${
            escapeXML bookmark.url
          }" ADD_DATE="1" LAST_MODIFIED="1"${
            lib.optionalString (bookmark.keyword != null)
            " SHORTCUTURL=\"${escapeXML bookmark.keyword}\""
          }${
            lib.optionalString (bookmark.tags != [ ])
            " TAGS=\"${escapeXML (concatStringsSep "," bookmark.tags)}\""
          }>${escapeXML bookmark.name}</A>'';

      directoryToHTML = indentLevel: directory: ''
        ${indent indentLevel}<DT>${
          if directory.toolbar then
            ''
              <H3 ADD_DATE="1" LAST_MODIFIED="1" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar''
          else
            ''<H3 ADD_DATE="1" LAST_MODIFIED="1">${escapeXML directory.name}''
        }</H3>
        ${indent indentLevel}<DL><p>
        ${allItemsToHTML (indentLevel + 1) directory.bookmarks}
        ${indent indentLevel}</DL><p>'';

      itemToHTMLOrRecurse = indentLevel: item:
        if item ? "url" then
          bookmarkToHTML indentLevel item
        else
          directoryToHTML indentLevel item;

      allItemsToHTML = indentLevel: bookmarks:
        lib.concatStringsSep "\n"
        (map (itemToHTMLOrRecurse indentLevel) bookmarks);

      bookmarkEntries = allItemsToHTML 1 bookmarks;
    in pkgs.writeText "bookmarks.html" ''
      <!DOCTYPE NETSCAPE-Bookmark-file-1>
      <!-- This is an automatically generated file.
        It will be read and overwritten.
        DO NOT EDIT! -->
      <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
      <TITLE>Bookmarks</TITLE>
      <H1>Bookmarks Menu</H1>
      <DL><p>
      ${bookmarkEntries}
      </DL>
    '';
in {
  options = {
    enable = mkOption {
      type = with types; bool;
      default = config.settings != [ ];
      description = "Whether to enable custom bookmarks.";
    };

    settings = mkOption {
      type = with types;
        coercedTo (attrsOf nodeType) attrValues (listOf nodeType);
      default = [ ];
      example = literalExpression ''
        [
          {
            name = "wikipedia";
            tags = [ "wiki" ];
            keyword = "wiki";
            url = "https://en.wikipedia.org/wiki/Special:Search?search=%s&go=Go";
          }
          {
            name = "kernel.org";
            url = "https://www.kernel.org";
          }
          {
            name = "Nix sites";
            toolbar = true;
            bookmarks = [
              {
                name = "homepage";
                url = "https://nixos.org/";
              }
              {
                name = "wiki";
                tags = [ "wiki" "nix" ];
                url = "https://wiki.nixos.org/";
              }
            ];
          }
        ]
      '';
      description = ''
        Preloaded bookmarks. Note, this may silently overwrite any
        previously existing bookmarks!
      '';
    };

    configFile = mkOption {
      type = with types; nullOr path;
      default = if config.enable then bookmarksFile config.settings else null;
      description = ''
        Configuration file to define custom bookmarks.
      '';
    };
  };
}
