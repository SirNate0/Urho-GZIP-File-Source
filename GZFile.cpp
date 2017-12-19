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

#include "../Core/Profiler.h"
#include "../IO/File.h"
#include "../IO/FileSystem.h"
#include "../IO/Log.h"
#include "../IO/MemoryBuffer.h"
#include "../IO/PackageFile.h"
#include <Urho3D/Core/Profiler.h>
#include <Urho3D/IO/File.h>
#include <Urho3D/IO/FileSystem.h>
#include <Urho3D/IO/Log.h>
#include <Urho3D/IO/MemoryBuffer.h>

#ifdef __ANDROID__
#include <SDL/SDL_rwops.h>
#endif

#include <cstdio>
#include "zlib/zlib.h"

#include "GZFile.h"


static const char* openMode[] =
{
    "rb",
    "wb",
    ""
};

namespace Urho3D
{


#ifdef __ANDROID__
const char* APK = "/apk/";
static const unsigned READ_BUFFER_SIZE = 32768;
#endif
static const unsigned SKIP_BUFFER_SIZE = 1024;

GZFile::GZFile(Context* context) :
    File(context),
    handle_(nullptr),
#ifdef __ANDROID__
    assetHandle_(0),
#endif
    readBufferOffset_(0),
    readBufferSize_(0),
    offset_(0),
    checksum_(0),
    readSyncNeeded_(false)
{
}

GZFile::GZFile(Context *context, const String &fileName, FileMode mode) :
    File(context),
    handle_(nullptr),
#ifdef __ANDROID__
    assetHandle_(0),
#endif
    readBufferOffset_(0),
    readBufferSize_(0),
    offset_(0),
    checksum_(0),
    readSyncNeeded_(false)
{
    Open(fileName, mode);
}

GZFile::GZFile(Context* context, FileSource* package, const String& fileName, FileMode mode) :
    File(context),
    handle_(nullptr),
#ifdef __ANDROID__
    assetHandle_(0),
#endif
    readBufferOffset_(0),
    readBufferSize_(0),
    offset_(0),
    checksum_(0),
    readSyncNeeded_(false)
{
    Open(package, fileName, mode);
}

GZFile::~GZFile()
{
    Close();
}


bool GZFile::Open(const String &fileName, FileMode mode)
{
    if (mode == FILE_READWRITE)
    {
        URHO3D_LOGERROR("Could not open gzipped file " + fileName + ".gz for both reading and writing.");
        return false;
    }

    bool success = OpenInternal(fileName + ".gz", mode);
    if (!success)
    {
        URHO3D_LOGERROR("Could not open gzipped file " + fileName + ".gz");
        return false;
    }

    fileName_ = fileName;

    // Seek to beginning of package entry's file data
    SeekInternal(offset_);
    return true;
}

bool GZFile::Open(FileSource *source, const String &fileName, FileMode mode)
{
    return Open(fileName, mode);
}

unsigned GZFile::Read(void* dest, unsigned size)
{
    if (!IsOpen())
    {
        // If file not open, do not log the error further here to prevent spamming the stderr stream
        return 0;
    }

    if (mode_ == FILE_WRITE)
    {
        URHO3D_LOGERROR("File not opened for reading");
        return 0;
    }

//    if (size + position_ > size_)
//        size = size_ - position_;
//    if (!size)
//        return 0;

    // Need to reassign the position due to internal buffering when transitioning from writing to reading
    if (readSyncNeeded_)
    {
        SeekInternal(position_);
        readSyncNeeded_ = false;
    }

    if (!ReadInternal(dest, size))
    {
        // Return to the position where the read began
        SeekInternal(position_);
        URHO3D_LOGERROR("Error while reading from gzipped file " + GetName());
        return 0;
    }

    writeSyncNeeded_ = true;
    position_ += size;
    return size;
}

unsigned GZFile::Seek(unsigned position)
{
    if (!IsOpen())
    {
        // If file not open, do not log the error further here to prevent spamming the stderr stream
        return 0;
    }

    // Allow sparse seeks if writing
    if (mode_ == FILE_READ && position > size_)
        position = size_;

    SeekInternal(position + offset_);
    position_ = position;
    readSyncNeeded_ = false;
    return position_;
}

unsigned GZFile::Write(const void* data, unsigned size)
{
    if (!IsOpen())
    {
        // If file not open, do not log the error further here to prevent spamming the stderr stream
        return 0;
    }

    if (mode_ == FILE_READ)
    {
        URHO3D_LOGERROR("File not opened for writing");
        return 0;
    }

    if (!size)
        return 0;

    // Need to reassign the position due to internal buffering when transitioning from reading to writing
    if (writeSyncNeeded_)
    {
        gzseek((gzFile)handle_, position_, SEEK_SET);
        writeSyncNeeded_ = false;
    }

    if (gzfwrite(data, size, 1, (gzFile)handle_) != 1)
    {
        // Return to the position where the write began
        gzseek((gzFile)handle_, position_, SEEK_SET);
        URHO3D_LOGERROR("Error while writing to file " + GetName());
        return 0;
    }

    readSyncNeeded_ = true;
    position_ += size;
    if (position_ > size_)
        size_ = position_;

    return size;
}

unsigned GZFile::GetChecksum()
{
    if (offset_ || checksum_)
        return checksum_;
    if (!handle_ || mode_ == FILE_WRITE)
        return 0;

    URHO3D_PROFILE(CalculateFileChecksum);

    unsigned oldPos = position_;
    checksum_ = 0;

    Seek(0);
    while (!IsEof())
    {
        unsigned char block[1024];
        unsigned readBytes = Read(block, 1024);
        for (unsigned i = 0; i < readBytes; ++i)
            checksum_ = SDBMHash(checksum_, block[i]);
    }

    Seek(oldPos);
    return checksum_;
}

void GZFile::Close()
{
    readBuffer_.Reset();
    inputBuffer_.Reset();

    if (handle_)
    {
        gzclose((gzFile)handle_);
        handle_ = nullptr;
        position_ = 0;
        size_ = -1;
        offset_ = 0;
        checksum_ = 0;
    }
}

void GZFile::Flush()
{
    if (handle_)
        gzflush((gzFile)handle_, Z_PARTIAL_FLUSH);
}

bool GZFile::IsEof() const
{
    if (handle_)
        gzeof((gzFile)handle_);
}

bool GZFile::IsOpen() const
{
    return handle_ != nullptr;
}

bool GZFile::OpenInternal(const String& fileName, FileMode mode)
{
    Close();

    readSyncNeeded_ = false;
    writeSyncNeeded_ = false;

    FileSystem* fileSystem = GetSubsystem<FileSystem>();
    if (fileSystem && !fileSystem->CheckAccess(GetPath(fileName)))
    {
        URHO3D_LOGERRORF("Access denied to %s", fileName.CString());
        return false;
    }

    if (fileName.Empty())
    {
        URHO3D_LOGERROR("Could not open file with empty name");
        return false;
    }

#ifdef __ANDROID__
    if (URHO3D_IS_ASSET(fileName))
    {
        URHO3D_LOGERROR("Cannot open gzipped android asset file. Not Implemented.");
        return false;
    }
#endif

    handle_ = gzopen(GetNativePath(fileName).CString(), openMode[mode]);

    if (!handle_)
    {
        URHO3D_LOGERRORF("Could not open file %s", fileName.CString());
        return false;
    }


    size_ = -1;//don't know size, so just say -1

    fileName_ = fileName;
    mode_ = mode;
    position_ = 0;
    //checksum_ = strm.adler;

    return true;
}

bool GZFile::ReadInternal(void* dest, unsigned size)
{
#ifdef __ANDROID__
    if (assetHandle_)
    {
        // Cannot read gzipped android asset files
        return false;
    }
    else
#endif
        return gzfread(dest, size, 1, (gzFile)handle_) == 1;
}

void GZFile::SeekInternal(unsigned newPosition)
{
#ifdef __ANDROID__
    if (assetHandle_)
    {
        // Cannot read gzipped android asset files
    }
    else
#endif
        gzseek((gzFile)handle_, newPosition, SEEK_SET);
}

}
