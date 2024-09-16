import React from 'react';

interface HtmlFromTextProps {
  style?: React.CSSProperties;
  htmlText: string;
}

const HtmlFromText: React.FC<HtmlFromTextProps> = ({ style, htmlText }) => {
  return (
    <div style={style} dangerouslySetInnerHTML={{ __html: htmlText }} />
  );
};

export default HtmlFromText;