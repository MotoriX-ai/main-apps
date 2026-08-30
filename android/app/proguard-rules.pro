# These classes are instantiated by name. R8 may retain the class while
# removing its otherwise-unused constructor, which crashes release builds.
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}
-keepclassmembers class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
