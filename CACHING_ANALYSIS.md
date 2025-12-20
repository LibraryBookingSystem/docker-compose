# Caching Analysis and Optimization

## Current Caching Setup

### ✅ What's Working

1. **Service Dockerfiles** - All use BuildKit cache mounts:
   ```dockerfile
   RUN --mount=type=cache,target=/root/.m2,id=maven-cache,sharing=shared \
       mvn dependency:go-offline -B
   ```
   - ✅ All services share the same cache ID (`maven-cache`)
   - ✅ Dependencies are cached across service builds
   - ✅ Cache persists during Docker BuildKit session

2. **setup.ps1** - Uses named volume for common-aspects:
   ```powershell
   docker run -v "library-maven-cache:/root/.m2" ...
   ```
   - ✅ Maven dependencies persist across runs
   - ⚠️ **BUT**: This cache is NOT shared with service BuildKit caches

### ⚠️ Issue: Cache Isolation

**Problem**: Two separate caching mechanisms:
- `setup.ps1` → Named volume (`library-maven-cache`)
- Service Dockerfiles → BuildKit cache mounts (`id=maven-cache`)

**Impact**: 
- Common-aspects dependencies are downloaded separately
- Service builds don't benefit from common-aspects dependency downloads
- Dependencies may be downloaded twice

## Optimization Options

### Option 1: Use BuildKit for Everything (Recommended)

**Approach**: Build common-aspects using Dockerfile with BuildKit

**Pros**:
- ✅ All builds use the same caching mechanism
- ✅ Dependencies truly shared
- ✅ Consistent build process

**Cons**:
- ⚠️ Requires extracting jar from container
- ⚠️ Slightly more complex setup

**Implementation**: Already started in `common-aspects/Dockerfile`

### Option 2: Use Named Volume for Everything

**Approach**: Mount named volume in service Dockerfiles

**Pros**:
- ✅ Simple and straightforward
- ✅ Cache persists across Docker restarts

**Cons**:
- ⚠️ Requires modifying all service Dockerfiles
- ⚠️ Less efficient than BuildKit cache mounts

### Option 3: Hybrid (Current + Documentation)

**Approach**: Keep current setup, document cache behavior

**Pros**:
- ✅ No changes needed
- ✅ Both caches work independently

**Cons**:
- ⚠️ Dependencies downloaded twice (once per cache)

## Recommended Solution

**Use Option 1** - BuildKit for everything:

1. ✅ Created `common-aspects/Dockerfile` with BuildKit cache mounts
2. ✅ Updated `setup.ps1` to use `docker build` instead of `docker run`
3. ✅ Enabled BuildKit globally in setup.ps1
4. ✅ All services already use BuildKit cache mounts

**Result**: 
- Common-aspects dependencies cached in BuildKit cache
- Service builds reuse the same cache
- Dependencies downloaded once, shared across all builds

## Verification

To verify caching is working:

```powershell
# First build - should download dependencies
.\setup.ps1

# Second build - should use cache (faster)
.\setup.ps1
```

Look for `CACHED` or `Using cache` messages in build output.



