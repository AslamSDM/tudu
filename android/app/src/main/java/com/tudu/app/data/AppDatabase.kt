package com.tudu.app.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverter
import androidx.room.TypeConverters
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

class Converters {
    private val serializer = ListSerializer(String.serializer())

    @TypeConverter
    fun tagsToString(tags: List<String>): String = Json.encodeToString(serializer, tags)

    @TypeConverter
    fun stringToTags(value: String): List<String> =
        runCatching { Json.decodeFromString(serializer, value) }.getOrDefault(emptyList())
}

@Database(entities = [TodoEntity::class], version = 1, exportSchema = true)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun todoDao(): TodoDao

    companion object {
        fun build(context: Context): AppDatabase =
            Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "tudu.db")
                .build()
    }
}
