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

#pragma once

#include <Urho3D/IO/FileSource.h>
#include "GZFile.h"

namespace Urho3D
{

/// Stores files of a directory tree sequentially for convenient access.
class URHO3D_API GZSource : public FileSource
{
    URHO3D_OBJECT(GZSource, FileSource);

public:
    /// Construct.
    GZSource(Context* context);
    /// Construct and open.
    GZSource(Context* context, const String& fileName);
    /// Destruct.
    virtual ~GZSource() override;

    /// Open the directory to map *.gz files in it to their uncompressed forms. Return true if successful.
    virtual bool Open(const String& fileName) override;
    /// Check if a file exists within the package file. This will be case-insensitive on Windows and case-sensitive on other platforms.
    virtual bool Exists(const String& fileName) const override;
    /// Get a GZFile from the package contents
    virtual GZFile *GetNewFile(const String& fileName, FileMode mode = FILE_READ) override;

    /// Return number of files.
    virtual unsigned GetNumFiles() const override { return GetEntryNames().Size(); }

    /// Return whether the files are compressed.
    virtual bool IsCompressed() const override { return true; }

    /// Return list of file names in the package.
    virtual const Vector<String> GetEntryNames() const override;

    /// Register object factory.
    static void RegisterObject(Context* context);

private:
};

}
