<?xml version="1.0" encoding="UTF-8"?>
  <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="text"/>
    <xsl:template match="/">
      return { <xsl:apply-templates/>
      }
    </xsl:template>

    <xsl:template match="Divinglog">
      <xsl:for-each select="Logbook/Dive">
        {
          start_date = "<xsl:value-of select="Divedate"/><xsl:text> </xsl:text><xsl:value-of select="Entrytime"/>:00",
          end_date = "",
          id = "",
          lat = "",
          lon = "",
          duration = <xsl:value-of select="Divetime * 60"/>,
          number = <xsl:value-of select="Number"/>,
          profile = {
            <xsl:for-each select="Profile/P">
              { runtime = <xsl:value-of select="@Time"/>,
                depth = <xsl:value-of select="Depth"/>,
                temperature = <xsl:value-of select="Temp"/>,
              },
            </xsl:for-each>
          },
        },
      </xsl:for-each>
    </xsl:template>

    <xsl:template match="dives">
      <xsl:for-each select="dive">
        {
          start_date = "<xsl:value-of select="date"/>",
          end_date = "",
          id = "",
          lat = "",
          lon = "",
          duration = <xsl:value-of select="duration"/>,
          number = <xsl:value-of select="diveNumber"/>,
          profile = {
            <xsl:for-each select="samples/sample">
              { runtime = <xsl:value-of select="time"/>,
                depth = <xsl:value-of select="depth"/>,
                temperature = <xsl:value-of select="temperature"/>,
              },
            </xsl:for-each>
          },
        },
      </xsl:for-each>
    </xsl:template>

    <xsl:template match="dive">
      <xsl:for-each select="diveLog">
        {
          start_date = "<xsl:call-template name="shearwater_date"><xsl:with-param name="d" select="startDate"/></xsl:call-template>",
          end_date = "<xsl:call-template name="shearwater_date"><xsl:with-param name="d" select="endDate"/></xsl:call-template>",
          id = "",
          lat = "",
          lon = "",
          duration = "",
          number = <xsl:value-of select="number"/>,
          profile = {
            <xsl:for-each select="diveLogRecords/diveLogRecord">
              { runtime = <xsl:value-of select="currentTime"/>,
                depth = <xsl:value-of select="currentDepth * 0.3048"/>,
                temperature = <xsl:value-of select="waterTemp"/>,
              },
            </xsl:for-each>
          },
        },
      </xsl:for-each>
    </xsl:template>

    <xsl:template match="uddf">
      <xsl:for-each select="profiledata/repetitiongroup">
        <xsl:for-each select="dive">
          {
            start_date = "<xsl:call-template name="uddf_date"><xsl:with-param name="d" select="informationbeforedive/datetime"/></xsl:call-template>",
            end_date = "",
            id = "",
            lat = "",
            lon = "",
            duration = <xsl:value-of select="informationafterdive/diveduration"/>,
            number = <xsl:value-of select="informationbeforedive/divenumber"/>,
            profile = {
              <xsl:for-each select="samples/waypoint">
                { runtime = <xsl:value-of select="divetime"/>,
                  depth = <xsl:value-of select="depth"/>,
                  temperature = <xsl:value-of select="temperature"/>,
                },
              </xsl:for-each>
            },
          },
        </xsl:for-each>
      </xsl:for-each>
    </xsl:template>

    <xsl:template name="shearwater_date">
      <xsl:param name="d"/>
      <xsl:variable name="rest" select="substring-after($d, ' ')"/>
      <xsl:variable name="mmm" select="substring-before($rest, ' ')"/>
      <xsl:variable name="rest2" select="substring-after($rest, ' ')"/>
      <xsl:variable name="dd" select="substring-before($rest2, ' ')"/>
      <xsl:variable name="rest3" select="substring-after($rest2, ' ')"/>
      <xsl:variable name="time" select="substring-before($rest3, ' ')"/>
      <xsl:variable name="rest4" select="substring-after($rest3, ' ')"/>
      <xsl:variable name="yyyy" select="substring-before($rest4, ' ')"/>
      <xsl:value-of select="$yyyy"/>-<xsl:choose>
        <xsl:when test="$mmm = 'Jan'">01</xsl:when>
        <xsl:when test="$mmm = 'Feb'">02</xsl:when>
        <xsl:when test="$mmm = 'Mar'">03</xsl:when>
        <xsl:when test="$mmm = 'Apr'">04</xsl:when>
        <xsl:when test="$mmm = 'May'">05</xsl:when>
        <xsl:when test="$mmm = 'Jun'">06</xsl:when>
        <xsl:when test="$mmm = 'Jul'">07</xsl:when>
        <xsl:when test="$mmm = 'Aug'">08</xsl:when>
        <xsl:when test="$mmm = 'Sep'">09</xsl:when>
        <xsl:when test="$mmm = 'Oct'">10</xsl:when>
        <xsl:when test="$mmm = 'Nov'">11</xsl:when>
        <xsl:when test="$mmm = 'Dec'">12</xsl:when>
      </xsl:choose>-<xsl:value-of select="$dd"/><xsl:text> </xsl:text><xsl:value-of select="$time"/>
    </xsl:template>

    <xsl:template name="uddf_date">
      <xsl:param name="d"/>
      <xsl:variable name="date" select="substring-before($d, 'T')"/>
      <xsl:variable name="time" select="substring-after($d, 'T')"/>
      <xsl:value-of select="$date"/><xsl:text> </xsl:text><xsl:value-of select="$time"/>
    </xsl:template>

</xsl:stylesheet>
