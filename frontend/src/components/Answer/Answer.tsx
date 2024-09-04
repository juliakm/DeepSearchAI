import { FormEvent, useContext, useEffect, useMemo, useState, useRef } from 'react'
import ReactMarkdown from 'react-markdown'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { nord } from 'react-syntax-highlighter/dist/esm/styles/prism'
import { Checkbox, DefaultButton, Dialog, FontIcon, Stack, Text } from '@fluentui/react'
import { useBoolean } from '@fluentui/react-hooks'
import { ThumbDislike20Filled, ThumbLike20Filled, Lightbulb24Regular } from '@fluentui/react-icons'
import DOMPurify from 'dompurify'
import remarkGfm from 'remark-gfm'
import supersub from 'remark-supersub'
import Plot from 'react-plotly.js'
import { AskResponse, Citation, Feedback, historyMessageFeedback } from '../../api'
import { XSSAllowTags, XSSAllowAttributes } from '../../constants/sanatizeAllowables'
import { AppStateContext } from '../../state/AppProvider'
import { parseAnswer } from './AnswerParser'
import styles from './Answer.module.css'

interface Props {
  answer: AskResponse
  onCitationClicked: (citedDocument: Citation) => void
  onExectResultClicked: () => void
}

export const Answer = ({ answer, onCitationClicked, onExectResultClicked }: Props) => {
  const [iconNameMD, setIconNameMD] = useState('Copy'); 
  const [iconNameTXT, setIconNameTXT] = useState('Copy'); 
  const [iconNameHTML, setIconNameHTML] = useState('Copy'); 
  const [iconColorMD, setIconColorMD] = useState(''); // Initially no color
  const [iconColorTXT, setIconColorTXT] = useState(''); // Initially no color
  const [iconColorHTML, setIconColorHTML] = useState(''); // Initially no color
  const [isHovered, setIsHovered] = useState(false);
  const buttonRef = useRef<HTMLButtonElement>(null);
  const hideTimeoutRef = useRef<number | null>(null);
  const [isHTMLCopyPopupVisible, setIsHTMLCopyPopupVisible] = useState(false);


  const handleMouseEnter = () => {
    // Clear any existing timeout to prevent premature hiding
    if (hideTimeoutRef.current) {
      clearTimeout(hideTimeoutRef.current);
    }
    setIsHovered(true);
    
  }
   
  const handleMouseLeave = () => {
    // Set a timeout to hide the buttons after 1 second
    hideTimeoutRef.current = setTimeout(() => {
      setIsHovered(false);
    }, 333);
  };

  function convertDivsToTables(htmlContent: string, tableWidth: string = '100%'): string {
    const parser = new DOMParser();
    const doc = parser.parseFromString(htmlContent, 'text/html');

    doc.querySelectorAll('div').forEach((div) => {
        const outerTable = document.createElement('table');
        outerTable.style.width = tableWidth;
        outerTable.style.maxWidth = tableWidth;
        outerTable.style.borderCollapse = 'collapse';
        outerTable.style.borderSpacing = '0';
        outerTable.style.margin = "0 auto"; // Center the table
        outerTable.setAttribute('width', tableWidth); // Ensure Gmail respects width

        const outerTr = document.createElement('tr');
        const outerTd = document.createElement('td');
        outerTd.style.padding = '0';
        outerTd.style.width = tableWidth; // Ensure Gmail respects width
        outerTd.setAttribute('width', tableWidth);

        // Inner table to contain the content
        const innerTable = document.createElement('table');
        innerTable.style.width = '100%';
        innerTable.style.borderCollapse = 'collapse';
        innerTable.style.wordWrap = 'break-word';
        innerTable.style.wordBreak = 'break-word'; // Ensure words break
        innerTable.style.whiteSpace = 'normal'; // Wrap text normally
        innerTable.style.tableLayout = 'fixed'; // Forces the table to respect widths
        innerTable.setAttribute('width', '100%');

        const innerTr = document.createElement('tr');
        const innerTd = document.createElement('td');
        if (div.classList.contains('code-section')) {
          innerTd.style.padding = '10px';
          innerTd.style.border = '1px solid #ccc';
          innerTd.style.backgroundColor = '#f9f9f9';
          innerTd.style.fontFamily = 'monospace';
          innerTd.style.borderRadius = '8px';
        }
        innerTd.innerHTML = div.innerHTML;

        innerTr.appendChild(innerTd);
        innerTable.appendChild(innerTr);

        outerTd.appendChild(innerTable);
        outerTr.appendChild(outerTd);
        outerTable.appendChild(outerTr);

        div.replaceWith(outerTable);
    });

    return new XMLSerializer().serializeToString(doc);
  }

  const copyToClipboard = (outputtype:string = "") => {
    if (outputtype == "") return;
    let content = "";
    if (outputtype == "markdown") content = parsedAnswer.markdownFormatText;
    if (outputtype == "text") content = document.querySelector(`.${styles.answerContainer}`)?.textContent || "";
    if (outputtype == "html") {
      const element = document.querySelector(`.${styles.answerContainer}`);
      
      const copyElement = document.getElementById("copyButtonContainer")
      const referenceNode = copyElement?.nextSibling;
      if (copyElement) {
        copyElement.remove();
      }

      if (element) {
        const blob = new Blob([convertDivsToTables(element.outerHTML, '750px')], { type: 'text/html' });
        const htmlcontent = [new ClipboardItem({ 'text/html': blob })];
        navigator.clipboard.write(htmlcontent);
        setIconNameHTML('CheckMark'); // Temporarily change the icon to "CheckMark"
        setIconColorHTML('green'); // Temporarily change the icon color to green
        setIsHTMLCopyPopupVisible(true);
        // Revert the icon back to "Copy" after 2 seconds
        setTimeout(() => {
          setIsHTMLCopyPopupVisible(false);
          setIconNameHTML('Copy');
          setIconColorHTML(''); // Revert the icon color back
        }, 3500);
      }
      
      if (copyElement) {
        referenceNode?.parentNode?.insertBefore(copyElement, referenceNode);
      }

    } else {
      navigator.clipboard.writeText(content).then(
        () => {
          if (outputtype == "markdown") {
            setIconNameMD('CheckMark'); // Temporarily change the icon to "CheckMark"
            setIconColorMD('green'); // Temporarily change the icon color to green
          }
          if (outputtype == "text") {
            setIconNameTXT('CheckMark'); // Temporarily change the icon to "CheckMark"
            setIconColorTXT('green'); // Temporarily change the icon color to green
          }
          // Revert the icon back to "Copy" after 2 seconds
          setTimeout(() => {
            if (outputtype == "markdown") {
               setIconNameMD('Copy');
               setIconColorMD(''); // Revert the icon color back
            }
            if (outputtype == "text") {
              setIconNameTXT('Copy');              
              setIconColorTXT(''); // Revert the icon color back
            } 
          }, 2000);
        },
        (err) => {
          console.error("Failed to copy html markdown: ", err);
        }
      );
    }
  };

  const initializeAnswerFeedback = (answer: AskResponse) => {
    if (answer.message_id == undefined) return undefined
    if (answer.feedback == undefined) return undefined
    if (answer.feedback.split(',').length > 1) return Feedback.Negative
    if (Object.values(Feedback).includes(answer.feedback)) return answer.feedback
    return Feedback.Neutral
  }

  const [isRefAccordionOpen, { toggle: toggleIsRefAccordionOpen }] = useBoolean(false)
  const filePathTruncationLimit = 50

  const parsedAnswer = useMemo(() => parseAnswer(answer), [answer])
  const [chevronIsExpanded, setChevronIsExpanded] = useState(isRefAccordionOpen)
  const [feedbackState, setFeedbackState] = useState(initializeAnswerFeedback(answer))
  const [isFeedbackDialogOpen, setIsFeedbackDialogOpen] = useState(false)
  const [showReportInappropriateFeedback, setShowReportInappropriateFeedback] = useState(false)
  const [negativeFeedbackList, setNegativeFeedbackList] = useState<Feedback[]>([])
  const appStateContext = useContext(AppStateContext)
  const FEEDBACK_ENABLED =
    appStateContext?.state.frontendSettings?.feedback_enabled && appStateContext?.state.isCosmosDBAvailable?.cosmosDB
  const SANITIZE_ANSWER = appStateContext?.state.frontendSettings?.sanitize_answer

  const handleChevronClick = () => {
    setChevronIsExpanded(!chevronIsExpanded)
    toggleIsRefAccordionOpen()
  }

  useEffect(() => {
    setChevronIsExpanded(isRefAccordionOpen)
  }, [isRefAccordionOpen])

  useEffect(() => {
    if (answer.message_id == undefined) return

    let currentFeedbackState
    if (appStateContext?.state.feedbackState && appStateContext?.state.feedbackState[answer.message_id]) {
      currentFeedbackState = appStateContext?.state.feedbackState[answer.message_id]
    } else {
      currentFeedbackState = initializeAnswerFeedback(answer)
    }
    setFeedbackState(currentFeedbackState)
  }, [appStateContext?.state.feedbackState, feedbackState, answer.message_id])

  const createCitationFilepath = (citation: Citation, index: number, truncate: boolean = false) => {
    let citationFilename = ''

    if (citation.filepath) {
      const part_i = citation.part_index ?? (citation.chunk_id ? parseInt(citation.chunk_id) + 1 : '')
      if (truncate && citation.filepath.length > filePathTruncationLimit) {
        const citationLength = citation.filepath.length
        citationFilename = `${citation.filepath.substring(0, 20)}...${citation.filepath.substring(citationLength - 20)} - Part ${part_i}`
      } else {
        citationFilename = `${citation.filepath} - Part ${part_i}`
      }
    } else if (citation.filepath && citation.reindex_id) {
      citationFilename = `${citation.filepath} - Part ${citation.reindex_id}`
    } else {
      citationFilename = `Citation ${index}`
    }
    return citationFilename
  }

  const onLikeResponseClicked = async () => {
    if (answer.message_id == undefined) return

    let newFeedbackState = feedbackState
    // Set or unset the thumbs up state
    if (feedbackState == Feedback.Positive) {
      newFeedbackState = Feedback.Neutral
    } else {
      newFeedbackState = Feedback.Positive
    }
    appStateContext?.dispatch({
      type: 'SET_FEEDBACK_STATE',
      payload: { answerId: answer.message_id, feedback: newFeedbackState }
    })
    setFeedbackState(newFeedbackState)

    // Update message feedback in db
    await historyMessageFeedback(answer.message_id, newFeedbackState)
  }

  const onDislikeResponseClicked = async () => {
    if (answer.message_id == undefined) return

    let newFeedbackState = feedbackState
    if (feedbackState === undefined || feedbackState === Feedback.Neutral || feedbackState === Feedback.Positive) {
      newFeedbackState = Feedback.Negative
      setFeedbackState(newFeedbackState)
      setIsFeedbackDialogOpen(true)
    } else {
      // Reset negative feedback to neutral
      newFeedbackState = Feedback.Neutral
      setFeedbackState(newFeedbackState)
      await historyMessageFeedback(answer.message_id, Feedback.Neutral)
    }
    appStateContext?.dispatch({
      type: 'SET_FEEDBACK_STATE',
      payload: { answerId: answer.message_id, feedback: newFeedbackState }
    })
  }

  const updateFeedbackList = (ev?: FormEvent<HTMLElement | HTMLInputElement>, checked?: boolean) => {
    if (answer.message_id == undefined) return
    const selectedFeedback = (ev?.target as HTMLInputElement)?.id as Feedback

    let feedbackList = negativeFeedbackList.slice()
    if (checked) {
      feedbackList.push(selectedFeedback)
    } else {
      feedbackList = feedbackList.filter(f => f !== selectedFeedback)
    }

    setNegativeFeedbackList(feedbackList)
  }

  const onSubmitNegativeFeedback = async () => {
    if (answer.message_id == undefined) return
    await historyMessageFeedback(answer.message_id, negativeFeedbackList.join(','))
    resetFeedbackDialog()
  }

  const resetFeedbackDialog = () => {
    setIsFeedbackDialogOpen(false)
    setShowReportInappropriateFeedback(false)
    setNegativeFeedbackList([])
  }

  const UnhelpfulFeedbackContent = () => {
    return (
      <>
        <div>Why wasn't this response helpful?</div>
        <Stack tokens={{ childrenGap: 4 }}>
          <Checkbox
            label="Citations are missing"
            id={Feedback.MissingCitation}
            defaultChecked={negativeFeedbackList.includes(Feedback.MissingCitation)}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="Citations are wrong"
            id={Feedback.WrongCitation}
            defaultChecked={negativeFeedbackList.includes(Feedback.WrongCitation)}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="The response is not from my data"
            id={Feedback.OutOfScope}
            defaultChecked={negativeFeedbackList.includes(Feedback.OutOfScope)}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="Inaccurate or irrelevant"
            id={Feedback.InaccurateOrIrrelevant}
            defaultChecked={negativeFeedbackList.includes(Feedback.InaccurateOrIrrelevant)}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="Other"
            id={Feedback.OtherUnhelpful}
            defaultChecked={negativeFeedbackList.includes(Feedback.OtherUnhelpful)}
            onChange={updateFeedbackList}></Checkbox>
        </Stack>
        <div onClick={() => setShowReportInappropriateFeedback(true)} style={{ color: '#115EA3', cursor: 'pointer' }}>
          Report inappropriate content
        </div>
      </>
    )
  }

  const ReportInappropriateFeedbackContent = () => {
    return (
      <>
        <div>
          The content is <span style={{ color: 'red' }}>*</span>
        </div>
        <Stack tokens={{ childrenGap: 4 }}>
          <Checkbox
            label="Hate speech, stereotyping, demeaning"
            id={Feedback.HateSpeech}
            defaultChecked={negativeFeedbackList.includes(Feedback.HateSpeech)}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="Violent: glorification of violence, self-harm"
            id={Feedback.Violent}
            defaultChecked={negativeFeedbackList.includes(Feedback.Violent)}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="Sexual: explicit content, grooming"
            id={Feedback.Sexual}
            defaultChecked={negativeFeedbackList.includes(Feedback.Sexual)}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="Manipulative: devious, emotional, pushy, bullying"
            defaultChecked={negativeFeedbackList.includes(Feedback.Manipulative)}
            id={Feedback.Manipulative}
            onChange={updateFeedbackList}></Checkbox>
          <Checkbox
            label="Other"
            id={Feedback.OtherHarmful}
            defaultChecked={negativeFeedbackList.includes(Feedback.OtherHarmful)}
            onChange={updateFeedbackList}></Checkbox>
        </Stack>
      </>
    )
  }

  const components = {
    code({ node, ...props }: { node: any;[key: string]: any }) {
      let language
      if (props.className) {
        const match = props.className.match(/language-(\w+)/)
        language = match ? match[1] : undefined
      }
      const codeString = node.children[0].value ?? ''
      return (
        <SyntaxHighlighter style={nord} language={language} PreTag="div" {...props}>
          {codeString}
        </SyntaxHighlighter>
      )
    }
  }
  return (
    <>
      <Stack className={styles.answerContainer} tabIndex={0} onMouseEnter={handleMouseEnter} onMouseLeave={handleMouseLeave} style={{position: 'relative'}} >
        <Stack.Item>
          <Stack horizontal grow>
            <Stack.Item grow>
              <ReactMarkdown
                linkTarget="_blank"
                remarkPlugins={[remarkGfm, supersub]}
                children={
                  SANITIZE_ANSWER
                    ? DOMPurify.sanitize(parsedAnswer.markdownFormatText, { ALLOWED_TAGS: XSSAllowTags, ALLOWED_ATTR: XSSAllowAttributes })
                    : parsedAnswer.markdownFormatText
                }
                className={styles.answerText}
                components={components}
              />
            </Stack.Item>

            {(isHovered && answer.answer.slice(-3) != "...") && (
            <Stack.Item className={styles.copyButtonContainer} id='copyButtonContainer' style={{position:'absolute', bottom: 0, right: 0}}>
              <DefaultButton
                title={"Copy markdown to text"}
                iconProps={{ iconName: iconNameTXT }}
                onClick={copyToClipboard.bind(this, "text")}
                onMouseEnter={()=> { if (buttonRef.current) { buttonRef.current.style.opacity = '1'; }}}
                onMouseLeave={()=> { if (buttonRef.current) { buttonRef.current.style.opacity = '.75'; }}}
                ariaLabel="Copy text to clipboard"
                styles={{
                  root: { position: 'absolute', bottom: '85px', right: '-15px', marginLeft: '5px', marginRight: 'auto', zIndex: 2, opacity: .75, width: '30px', height: '30px', minWidth: '30px', padding: '0px', borderRadius: '8%', backgroundColor: 'white', boxShadow: '0px 2px 4px rgba(0, 0, 0, 0.1)', cursor: 'pointer' },
                  icon: { fontSize: '11px', color: iconColorTXT }
                }}
              />
              <div onClick={copyToClipboard.bind(this, "text")} title="Copy text to clipboard" style={{ position: 'absolute', bottom: '86px', right: '-8px',  userSelect: 'none', fontStyle: 'bold', fontFamily: 'Courier, monospace', fontSize: '9px', zIndex: 3, cursor: 'pointer' }}>
                txt
              </div>
              <DefaultButton
                title="Copy markdown to clipboard"
                iconProps={{ iconName: iconNameMD }}
                onClick={copyToClipboard.bind(this, "markdown")}
                onMouseEnter={()=> { if (buttonRef.current) { buttonRef.current.style.opacity = '1'; }}}
                onMouseLeave={()=> { if (buttonRef.current) { buttonRef.current.style.opacity = '.75'; }}}
                ariaLabel="Copy markdown to clipboard"
                styles={{
                  root: { position: 'absolute', bottom: '52px', right: '-15px', marginLeft: '5px', marginRight: 'auto', zIndex: 2, opacity: .75, width: '30px', height: '30px', minWidth: '30px', padding: '0px', borderRadius: '8%', backgroundColor: 'white', boxShadow: '0px 2px 4px rgba(0, 0, 0, 0.1)', cursor: 'pointer' },
                  icon: { fontSize: '11px', color: iconColorMD }
                }}
              />
              <div onClick={copyToClipboard.bind(this, "markdown")} title="Copy markdown to clipboard" style={{ position: 'absolute', bottom: '53px', right: '-5px',  userSelect: 'none', fontStyle: 'bold', fontFamily: 'Courier, monospace', fontSize: '9px', zIndex: 3, cursor: 'pointer' }}>
                md
              </div>
              <DefaultButton
                  title="Copy html to clipboard"
                  iconProps={{ iconName: iconNameHTML }}
                  onClick={copyToClipboard.bind(this, "html")}
                  onMouseEnter={()=> { if (buttonRef.current) { buttonRef.current.style.opacity = '1'; }}}
                  onMouseLeave={()=> { if (buttonRef.current) { buttonRef.current.style.opacity = '.75'; }}}
                  ariaLabel="Copy html to clipboard"
                  styles={{
                    root: { position: 'absolute', bottom: '20px', right: '-15px', marginLeft: '5px', marginRight: 'auto', zIndex: 2, opacity: .75, width: '30px', height: '30px', minWidth: '30px', padding: '0px', borderRadius: '8%', backgroundColor: 'white', boxShadow: '0px 2px 4px rgba(0, 0, 0, 0.1)', cursor: 'pointer' },
                    icon: { fontSize: '11px', color: iconColorHTML }
                  }}
                />
                <div onClick={copyToClipboard.bind(this, "html")} title="Copy html to clipboard" style={{ position: 'absolute', bottom: '21px', right: '-12px',  userSelect: 'none', fontStyle: 'bold', fontFamily: 'Courier, monospace', fontSize: '9px', zIndex: 3, cursor: 'pointer' }}>
                  html
                </div>
            </Stack.Item>)}
            {isHTMLCopyPopupVisible && (
                    <div style={{
                        position: 'absolute',
                        bottom: '40px', // Adjust to position above the button
                        right: '-205px',
                        backgroundColor: 'rgba(240, 225, 225, 1)',
                        color: 'black',
                        padding: '6px 12px',
                        borderRadius: '5px',
                        borderColor: 'rgba(200, 200, 200, .7)',
                        borderWidth: '1px',
                        transform: 'translateX(-50%)',
                        zIndex: 1000,
                        whiteSpace: 'nowrap',
                        fontSize: '14px',
                    }}>
                        <b><Lightbulb24Regular style={{ marginRight: '8px', verticalAlign: 'middle', color: 'green' }} />Tip on copied HTML</b><br/>
                        Paste with <i>Keep source formatting</i> for best results in Office apps.
                    </div>
                )
            }
            <Stack.Item className={styles.answerHeader}>
              {FEEDBACK_ENABLED && answer.message_id !== undefined && (
                <Stack horizontal horizontalAlign="space-between">
                  <ThumbLike20Filled
                    aria-hidden="false"
                    aria-label="Like this response"
                    onClick={() => onLikeResponseClicked()}
                    style={
                      feedbackState === Feedback.Positive ||
                        appStateContext?.state.feedbackState[answer.message_id] === Feedback.Positive
                        ? { color: 'darkgreen', cursor: 'pointer' }
                        : { color: 'slategray', cursor: 'pointer' }
                    }
                  />
                  <ThumbDislike20Filled
                    aria-hidden="false"
                    aria-label="Dislike this response"
                    onClick={() => onDislikeResponseClicked()}
                    style={
                      feedbackState !== Feedback.Positive &&
                        feedbackState !== Feedback.Neutral &&
                        feedbackState !== undefined
                        ? { color: 'darkred', cursor: 'pointer' }
                        : { color: 'slategray', cursor: 'pointer' }
                    }
                  />
                </Stack>
              )}
            </Stack.Item>
          </Stack>
        </Stack.Item>
        {parsedAnswer.plotly_data !== null && (
          <Stack className={styles.answerContainer}>
            <Stack.Item grow>
              <Plot data={parsedAnswer.plotly_data.data} layout={parsedAnswer.plotly_data.layout} />
            </Stack.Item>
          </Stack>
        )}
        <Stack horizontal className={styles.answerFooter}>
          {!!parsedAnswer.citations.length && (
            <Stack.Item onKeyDown={e => (e.key === 'Enter' || e.key === ' ' ? toggleIsRefAccordionOpen() : null)}>
              <Stack style={{ width: '100%' }}>
                <Stack horizontal horizontalAlign="start" verticalAlign="center">
                  <Text
                    className={styles.accordionTitle}
                    onClick={toggleIsRefAccordionOpen}
                    aria-label="Open references"
                    tabIndex={0}
                    role="button">
                    <span>
                      {parsedAnswer.citations.length > 1
                        ? parsedAnswer.citations.length + ' references'
                        : '1 reference'}
                    </span>
                  </Text>
                  <FontIcon
                    className={styles.accordionIcon}
                    onClick={handleChevronClick}
                    iconName={chevronIsExpanded ? 'ChevronDown' : 'ChevronRight'}
                  />
                </Stack>
              </Stack>
            </Stack.Item>
          )}
          <Stack.Item className={styles.answerDisclaimerContainer}>
            <span className={styles.answerDisclaimer}>AI-generated content may be incorrect</span>
          </Stack.Item>
          {!!answer.exec_results?.length && (
            <Stack.Item onKeyDown={e => (e.key === 'Enter' || e.key === ' ' ? toggleIsRefAccordionOpen() : null)}>
              <Stack style={{ width: '100%' }}>
                <Stack horizontal horizontalAlign="start" verticalAlign="center">
                  <Text
                    className={styles.accordionTitle}
                    onClick={() => onExectResultClicked()}
                    aria-label="Open Intents"
                    tabIndex={0}
                    role="button">
                    <span>
                      Show Intents
                    </span>
                  </Text>
                  <FontIcon
                    className={styles.accordionIcon}
                    onClick={handleChevronClick}
                    iconName={'ChevronRight'}
                  />
                </Stack>
              </Stack>
            </Stack.Item>
          )}
        </Stack>
        {chevronIsExpanded && (
          <div className={styles.citationWrapper}>
            {parsedAnswer.citations.map((citation, idx) => {
              return (
                <span
                  title={createCitationFilepath(citation, ++idx)}
                  tabIndex={0}
                  role="link"
                  key={idx}
                  onClick={() => onCitationClicked(citation)}
                  onKeyDown={e => (e.key === 'Enter' || e.key === ' ' ? onCitationClicked(citation) : null)}
                  className={styles.citationContainer}
                  aria-label={createCitationFilepath(citation, idx)}>
                  <div className={styles.citation}>{idx}</div>
                  {createCitationFilepath(citation, idx, true)}
                </span>
              )
            })}
          </div>
        )}
      </Stack>
      <Dialog
        onDismiss={() => {
          resetFeedbackDialog()
          setFeedbackState(Feedback.Neutral)
        }}
        hidden={!isFeedbackDialogOpen}
        styles={{
          main: [
            {
              selectors: {
                ['@media (min-width: 480px)']: {
                  maxWidth: '600px',
                  background: '#FFFFFF',
                  boxShadow: '0px 14px 28.8px rgba(0, 0, 0, 0.24), 0px 0px 8px rgba(0, 0, 0, 0.2)',
                  borderRadius: '8px',
                  maxHeight: '600px',
                  minHeight: '100px'
                }
              }
            }
          ]
        }}
        dialogContentProps={{
          title: 'Submit Feedback',
          showCloseButton: true
        }}>
        <Stack tokens={{ childrenGap: 4 }}>
          <div>Your feedback will improve this experience.</div>

          {!showReportInappropriateFeedback ? <UnhelpfulFeedbackContent /> : <ReportInappropriateFeedbackContent />}

          <div>By pressing submit, your feedback will be visible to the application owner.</div>

          <DefaultButton disabled={negativeFeedbackList.length < 1} onClick={onSubmitNegativeFeedback}>
            Submit
          </DefaultButton>
        </Stack>
      </Dialog>
    </>
  )
}
