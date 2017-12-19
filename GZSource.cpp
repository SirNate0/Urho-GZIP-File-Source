//
// Copyright (c) 2008-2017 the Urho3D project.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#include "../Precompiled.h"

#include <Urho3D/Core/Context.h>
#include <Urho3D/IO/SystemFile.h>
#include <Urho3D/IO/FileSystem.h>
#include <Urho3D/IO/Log.h>
#include "GZSource.h"

namespace Urho3D
{

extern const char* FILESOURCE_CATEGORY;

GZSource::GZSource(Context* context) :
    FileSource(context)
{
}

GZSource::GZSource(Context* context, const String& fileName) :
    FileSource(context)
{
    Open(fileName);
}

GZSource::~GZSource()
{
}

bool GZSource::Open(const String& fileName)
{
    //If this is not a directory, return false.
    if (!GetSubsystem<FileSystem>()->DirExists(fileName))
    {
        URHO3D_LOGDEBUG("Tried to open " + fileName + " as gzip file directory.");
        return false;
    }

    // TODO: Possibly allow a single gzipped file to be opened as the source (with one entry)

    fileName_ = fileName;
    nameHash_ = fileName_;

    return true;
}

bool GZSource::Exists(const String& fileName) const
{
    return GetSubsystem<FileSystem>()->FileExists(AddTrailingSlash(fileName_) + fileName + ".gz");
}

GZFile* GZSource::GetNewFile(const String &fileName, FileMode mode)
{
    return new GZFile(context_,this,AddTrailingSlash(fileName_) + fileName,mode);
}

const Vector<String> GZSource::GetEntryNames() const
{
    if (fileName_.Empty())
        return {};

    FileSystem* fileSystem = GetSubsystem<FileSystem>();
    Vector<String> entries;
    fileSystem->ScanDir(entries, fileName_, "*.gz", SCAN_FILES | SCAN_HIDDEN, true);
    for (String& s : entries)
    {
        s = s.Substring(0,s.Length()-3);//Remove the .gz extension
    }
    return entries;
}
void GZSource::RegisterObject(Context *context)
{
    context->RegisterFactory<GZSource>();
}

}
