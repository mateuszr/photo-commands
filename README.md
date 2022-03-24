# PhotoCommands

A simple command line tool for managing photos in Photos.app.
The goal is to provide some functionalities to help organizing photos, such as
filtering by EXIF metadata, image properties, removing duplicates, etc.
This might be especially useful when dumping photo roll from iPhone to Photos Library.
In such case you might end up with having a mix of pictures from camera, whatsapp and other
IM communicators, pictures saved from the internet, duplicated pictures (due to bug in importing photos), etc.


The current version handles only:
- finding pictures not taken by Apple device (iPhone, iPad), e.g. downloaded pictures that are not photos
- finding duplicates, i.e. pictures that has the same SHA-256 hash.

If one of those options is selected, the action is performed in the chosen photo album. Note that the tool will neither remove the pictures, nor move them another album. Found pictures will be selected as favourites and user can review and decide later what to do, e.g. move them or delete.
When scanning for duplicates, only duplicate photo(s) will be marked as favourite, the orginal one will not be marked as favourite. The "original one" is simply the first one encountered (the oldest added to the Library).


# Building

You need to have xcode and `swift` command.
To build the executable run the following:
```
git clone git@github.com:mateuszr/photo-commands.git
cd photo-commands
swift build
```

Running:
```
.build/x86_64-apple-macosx/debug/photo-commands -h
```


# Sample usage

First of all: you can't select a custom Photo Library. The tool will use your default  (system) Photos library. You can change the system Photos library in Photos app preferences.

To get the list of albums run with `-l` option:

```
$ photo-commands -l
Listing all albums
id: F80678A7-3D3C-4838-B7C6-B30568BE1895/L0/040    count: 534    start date: 2020-07-05 14:34:12 +0000    end date: 2020-07-05 19:39:06 +0000    name: First Album
id: 8FD96F38-2122-4083-B28A-0BE6130830DE/L0/040    count: 1    start date: 2011-12-13 11:52:02 +0000    end date: 2011-12-13 11:52:02 +0000    name: Second Album
id: 64B794FB-F8EC-4D66-9696-177B4833104C/L0/040    count: 1    start date: 2011-12-26 03:04:12 +0000    end date: 2011-12-26 03:04:12 +0000    name: Some other Album
```

Now, having the id of your album you can e.g. find all duplicates:
```
$ photo-commands -d "F80678A7-3D3C-4838-B7C6-B30568BE1895/L0/040"
```

*Note that before that it is best if you have no favourite photos in the album. The command will mark all duplicates as favourites.*
After that you can go to Photos, select your album, select "show only favourites", and then select all and remove them.


#  Command-line agruments

```
USAGE: photo-commands [--list] [--count] [--list-photos] [--find-non-apple-photos] [--find-duplicates] [--silent] [<album-id>]

ARGUMENTS:
  <album-id>              Id of the album (as returned by -l command)

OPTIONS:
  -l, --list              List all albums with some metadata.
  -c, --count             Count all photos in library.
  -L, --list-photos       List photos in an album with basic metadata. Requires <albumId> argument.
  -f, --find-non-apple-photos
                          Find images that are not photos. Requires <albumId> argument.
  -d, --find-duplicates   Find duplicate images. Requires <albumId> argument.
  -s, --silent            Silent mode. Showing only summary at the end when looking for duplicates.
  -h, --help              Show help information.

```
